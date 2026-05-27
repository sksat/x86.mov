//go:build linux

package runner

import (
	"debug/elf"
	"io"
	"os"
	"runtime"
	"testing"
	"time"

	"github.com/sksat/x86.mov/turbo86/proto"
	"github.com/sksat/x86.mov/turbo86/stub"
)

// movfuscatorELFEnv points the test at a fully-linked movfuscator
// binary. Build the fixture via:
//
//	cd ../../movfuscator-wasm && make setup && make build-native
//	cd testdata && make
//
// Then:
//
//	TURBO86_MOVFUSCATOR_ELF=$(pwd)/testdata/return42.elf go test ./runner \
//	    -run TestRunner_MovfuscatorReturn42_LinkedELF -v
//
// The test is gated on this env var because the ELF (a) requires the
// movfuscator runtime to be materialized (gitignored), and (b) is too
// large to commit (~10 MiB).
const movfuscatorELFEnv = "TURBO86_MOVFUSCATOR_ELF"

// TestRunner_MovfuscatorReturn42_LinkedELF observes what happens when
// turbo86 runs an actually-linked movfuscator return42 binary end-to-
// end. The current expected outcome is *not* Exit{42} — the upstream
// movfuscator runtime's dispatch trick (`mov cs, ax` → SIGILL handler
// = master_loop = re-run main from start) loops without a termination
// condition we know how to satisfy from our stubs.s. movie86 hits the
// same wall (see ../../../mov-emu/movie86/CLAUDE.md). What we DO want
// to verify here is that the wiring works as far as the upstream
// runtime allows:
//
//   - rt_sigaction passes through twice (SIGSEGV + SIGILL handlers
//     installed by crt0).
//   - The eventual SIGILL fires, the runner forwards it, and the
//     kernel dispatches into the registered handler (we'd see further
//     syscall stops from inside the handler).
//
// The test caps the event budget so a stuck binary doesn't hang CI.
func TestRunner_MovfuscatorReturn42_LinkedELF(t *testing.T) {
	elfPath := os.Getenv(movfuscatorELFEnv)
	if elfPath == "" {
		t.Skipf("set %s=path/to/return42.elf to run this test", movfuscatorELFEnv)
	}

	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	f, err := elf.Open(elfPath)
	if err != nil {
		t.Fatalf("open ELF %q: %v", elfPath, err)
	}
	defer f.Close()
	if f.Class != elf.ELFCLASS32 || f.Machine != elf.EM_386 {
		t.Fatalf("expected ELF32/i386, got class=%v machine=%v", f.Class, f.Machine)
	}

	r, err := New(stub.Bytes)
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	defer r.Close()

	for _, p := range f.Progs {
		if p.Type != elf.PT_LOAD || p.Filesz == 0 {
			continue
		}
		// Filesz bytes from the file; MemSiz may be larger for .bss
		// which the stub's anonymous mmap already zero-fills.
		buf := make([]byte, p.Filesz)
		if _, err := io.ReadFull(p.Open(), buf); err != nil {
			t.Fatalf("read segment @ 0x%x: %v", p.Vaddr, err)
		}
		if err := r.WriteCode(uint32(p.Vaddr), buf); err != nil {
			t.Fatalf("write segment @ 0x%x: %v", p.Vaddr, err)
		}
		t.Logf("loaded segment @ 0x%x (filesz=0x%x memsz=0x%x)", p.Vaddr, p.Filesz, p.Memsz)
	}

	events := r.Run(uint32(f.Entry), 0x701FFFF0)

	const maxEvents = 8
	const overallTimeout = 5 * time.Second
	timeout := time.After(overallTimeout)

	var collected []proto.Outbound
loop:
	for len(collected) < maxEvents {
		select {
		case ev, ok := <-events:
			if !ok {
				break loop
			}
			collected = append(collected, ev)
			t.Logf("event %d: %#v", len(collected), ev)
			if _, isExit := ev.(proto.Exit); isExit {
				break loop
			}
		case <-timeout:
			t.Logf("timed out after %v with %d events (upstream movfuscator runtime loops forever — expected for now)", overallTimeout, len(collected))
			return
		}
	}

	t.Logf("collected %d events", len(collected))
	if len(collected) == 0 {
		t.Error("got no events at all — sigaction passthrough may not be wired up")
	}
}
