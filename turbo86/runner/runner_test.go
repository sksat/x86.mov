//go:build linux

package runner

import (
	"bytes"
	"reflect"
	"runtime"
	"testing"

	"github.com/sksat/x86.mov/turbo86/proto"
	"github.com/sksat/x86.mov/turbo86/stub"
)

// Top of the guest stack region the stub maps for us (0x70000000..0x70200000).
// Picked well clear of the stub's own initial stack (~0xBFFFFFF0).
const testStackTop = 0x701FFFF0

// TestRunOnce_ExitFortyTwo is the headline integration test for native
// execution: hand-assembled mov-only exit(42) bytes go through the same
// pipeline a streaming frontend would drive — and the bridge emits the
// expected Exit{42}.
func TestRunOnce_ExitFortyTwo(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	//   B8 01 00 00 00         mov eax, 1     ; SYS_exit
	//   BB 2A 00 00 00         mov ebx, 42    ; status
	//   CD 80                  int 0x80
	code := []byte{
		0xB8, 0x01, 0x00, 0x00, 0x00,
		0xBB, 0x2A, 0x00, 0x00, 0x00,
		0xCD, 0x80,
	}
	const entry uint32 = 0x08048000

	events, err := RunOnce(stub.Bytes, map[uint32][]byte{entry: code}, entry, testStackTop)
	if err != nil {
		t.Fatalf("RunOnce: %v", err)
	}
	want := []proto.Outbound{proto.Exit{Code: 42}}
	if !reflect.DeepEqual(events, want) {
		t.Errorf("events:\n  got:  %#v\n  want: %#v", events, want)
	}
}

// TestRunOnce_WriteThenExit checks that write(1, "hi", 2) is bridged
// to a Stdout event and the subsequent exit(0) closes the session.
func TestRunOnce_WriteThenExit(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const entry uint32 = 0x08048000
	const bufAddr uint32 = 0x08048100

	//   B8 04 00 00 00         mov eax, 4         ; SYS_write
	//   BB 01 00 00 00         mov ebx, 1         ; fd = stdout
	//   B9 00 81 04 08         mov ecx, 0x08048100; buf
	//   BA 02 00 00 00         mov edx, 2         ; len
	//   CD 80                  int 0x80
	//   B8 01 00 00 00         mov eax, 1         ; SYS_exit
	//   BB 00 00 00 00         mov ebx, 0         ; status
	//   CD 80                  int 0x80
	code := []byte{
		0xB8, 0x04, 0x00, 0x00, 0x00,
		0xBB, 0x01, 0x00, 0x00, 0x00,
		0xB9, 0x00, 0x81, 0x04, 0x08,
		0xBA, 0x02, 0x00, 0x00, 0x00,
		0xCD, 0x80,
		0xB8, 0x01, 0x00, 0x00, 0x00,
		0xBB, 0x00, 0x00, 0x00, 0x00,
		0xCD, 0x80,
	}

	events, err := RunOnce(
		stub.Bytes,
		map[uint32][]byte{
			entry:   code,
			bufAddr: []byte("hi"),
		},
		entry,
		testStackTop,
	)
	if err != nil {
		t.Fatalf("RunOnce: %v", err)
	}
	want := []proto.Outbound{
		proto.Stdout{Bytes: []byte("hi")},
		proto.Exit{Code: 0},
	}
	if !reflect.DeepEqual(events, want) {
		t.Errorf("events:\n  got:  %#v\n  want: %#v", events, want)
	}
}

// TestRunOnce_NullDerefBecomesPaused exercises the recoverable-stop
// path: a guest write to the unmapped null page raises SIGSEGV, which
// the runner surfaces as Paused (not Fault) with the regs at the
// faulting instruction. This is the structural prerequisite for handing
// the session to movie86 to handle e.g. the movfuscator SIGSEGV
// dispatch trick.
func TestRunOnce_NullDerefBecomesPaused(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const entry uint32 = 0x08048000
	//   B8 EF BE AD DE              mov eax, 0xDEADBEEF   ; (5 bytes)
	//   89 05 00 00 00 00           mov DWORD PTR [0], eax; (6 bytes; faults)
	code := []byte{
		0xB8, 0xEF, 0xBE, 0xAD, 0xDE,
		0x89, 0x05, 0x00, 0x00, 0x00, 0x00,
	}

	events, err := RunOnce(stub.Bytes, map[uint32][]byte{entry: code}, entry, testStackTop)
	if err != nil {
		t.Fatalf("RunOnce: %v", err)
	}
	if len(events) != 1 {
		t.Fatalf("expected 1 event, got %d: %#v", len(events), events)
	}
	paused, ok := events[0].(proto.Paused)
	if !ok {
		t.Fatalf("expected Paused, got %T: %#v", events[0], events[0])
	}
	if paused.Signal != 11 {
		t.Errorf("Signal: got %d, want 11 (SIGSEGV)", paused.Signal)
	}
	// The first mov should have completed before the second faulted.
	if paused.Regs.Eax != 0xDEADBEEF {
		t.Errorf("Regs.Eax: got 0x%x, want 0xDEADBEEF (post-first-mov)", paused.Regs.Eax)
	}
	// EIP must point AT the faulting instruction (offset 5), not past
	// it — otherwise a peer engine resuming via LoadContext would skip
	// the operation the original engine couldn't perform.
	if want := entry + 5; paused.Regs.Eip != want {
		t.Errorf("Regs.Eip: got 0x%x, want 0x%x (faulting mov [0], eax)", paused.Regs.Eip, want)
	}

	// Two non-zero pages now: the entry-point page with the guest's
	// 11 bytes of code, plus the runtime-installed trampoline page at
	// 0x09040000 (CD 80 used for mov-only ABI mmap_request injection,
	// and rt_sigreturn in trap mode). Everything else in the 16 MiB
	// code region and the 2 MiB stack region is demand-zero.
	if len(paused.Regions) != 2 {
		t.Fatalf("Regions: got %d entries, want 2: %#v", len(paused.Regions), paused.Regions)
	}
	r := paused.Regions[0]
	if r.Addr != entry {
		t.Errorf("Regions[0].Addr: got 0x%x, want 0x%x", r.Addr, entry)
	}
	if len(r.Bytes) != 4096 {
		t.Errorf("Regions[0].Bytes len: got %d, want 4096 (one page)", len(r.Bytes))
	}
	if !bytes.Equal(r.Bytes[:len(code)], code) {
		t.Errorf("Regions[0].Bytes[:len(code)]:\n  got:  % x\n  want: % x", r.Bytes[:len(code)], code)
	}
	tramp := paused.Regions[1]
	if tramp.Addr != 0x09040000 {
		t.Errorf("Regions[1].Addr (trampoline): got 0x%x, want 0x09040000", tramp.Addr)
	}
	wantTramp := []byte{0xB8, 0xAD, 0x00, 0x00, 0x00, 0xCD, 0x80}
	if !bytes.Equal(tramp.Bytes[:len(wantTramp)], wantTramp) {
		t.Errorf("Regions[1].Bytes prefix (trampoline):\n  got:  % x\n  want: % x",
			tramp.Bytes[:len(wantTramp)], wantTramp)
	}
}
