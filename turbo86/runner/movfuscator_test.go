//go:build linux

package runner

import (
	"debug/elf"
	"runtime"
	"testing"

	"github.com/sksat/x86.mov/turbo86/proto"
	"github.com/sksat/x86.mov/turbo86/stub"
)

// TestRunOnce_MovfuscatorReturn42_TextStreams streams the .text of the
// committed `return42.o` (the smallest movfuscator-built example) into
// turbo86 without performing the link step. The movfuscator runtime
// objects (alu_*, R0..R3, target, sel_data, …) are gitignored and not
// built here, so absolute references in the raw .text resolve to address
// 0 — guest execution faults early.
//
// What this test demonstrates:
//   - turbo86 accepts real movfuscator-produced bytes through the same
//     Code-then-Start streaming path the frontend will drive.
//   - The failure mode is graceful: a single Fault event closes the
//     session, no host-side crash, no stuck child process.
//
// What it does NOT yet prove (planned follow-ups):
//   - Full execution to exit(42). Needs the runtime objects materialized
//     (`cd movfuscator-wasm && make setup && make build-native`) and
//     linked in, plus syscall passthrough on the runner side so the
//     SIGILL/SIGSEGV dispatch handlers can be registered via sigaction.
func TestRunOnce_MovfuscatorReturn42_TextStreams(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	// Path is relative to this package directory (turbo86/runner/),
	// which is also `go test`'s working directory.
	const fixturePath = "../../movfuscator-wasm/tests/goldens-o/return42.o"

	f, err := elf.Open(fixturePath)
	if err != nil {
		t.Fatalf("open fixture %q: %v", fixturePath, err)
	}
	defer f.Close()

	if f.Class != elf.ELFCLASS32 || f.Machine != elf.EM_386 {
		t.Fatalf("fixture not ELF32/i386: class=%v machine=%v", f.Class, f.Machine)
	}

	textSec := f.Section(".text")
	if textSec == nil {
		t.Fatal(".text section not found in return42.o")
	}
	textBytes, err := textSec.Data()
	if err != nil {
		t.Fatalf("read .text: %v", err)
	}
	t.Logf("streaming .text: %d bytes", len(textBytes))

	// Place .text at the conventional i386 ELF base. Internal offsets
	// inside .text are relative-to-zero (the section's sh_addr), so the
	// guest's view of "EIP - base" matches the .o's encoding.
	const base uint32 = 0x08048000
	const stackTop uint32 = 0x701FFFF0

	events, runErr := RunOnce(
		stub.Bytes,
		map[uint32][]byte{base: textBytes},
		base,
		stackTop,
	)

	// RunOnce error path is for *runner* failures (ptrace, memfd, …).
	// A guest fault is a normal end-of-session, surfaced via the event
	// stream, not via the Go error return.
	if runErr != nil {
		t.Fatalf("RunOnce returned host-side error: %v", runErr)
	}
	if len(events) == 0 {
		t.Fatal("no events emitted; expected at least a Fault")
	}

	final := events[len(events)-1]
	if _, ok := final.(proto.Fault); !ok {
		t.Errorf("final event: got %T %#v, want proto.Fault", final, final)
	}
	for i, ev := range events {
		t.Logf("  event %d: %#v", i, ev)
	}
}
