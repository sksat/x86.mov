//go:build linux

package runner

import (
	"reflect"
	"runtime"
	"testing"

	"github.com/sksat/x86.mov/turbo86/proto"
	"github.com/sksat/x86.mov/turbo86/stub"
)

// TestRunner_WriteCodeWhileRunning exercises the streaming primitive:
// the runner is mid-session (between syscall stops) when the caller
// writes additional guest memory. The /proc/PID/mem write must succeed
// — that's the foundation for the WS server's "post-Start Code"
// streaming.
//
// Guest program: write(1, "A", 1); exit(42)  (two syscalls, no branches)
// Test sequence:
//   1. New + WriteCode (initial program) + Run.
//   2. Receive Stdout("A") — confirms the first syscall has been
//      processed and the child is between syscalls.
//   3. Call WriteCode at an address the guest never reads; this is
//      the streaming write that must not error mid-session.
//   4. Receive Exit{42}.
//   5. Drain the channel close.
func TestRunner_WriteCodeWhileRunning(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const entry uint32 = 0x08048000
	const aAddr uint32 = 0x08048100   // where "A" is stored, read by write(2)
	const lateAddr uint32 = 0x08049000 // the post-Run write target

	r, err := New(stub.Bytes)
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	defer r.Close()

	//   B8 04 00 00 00         mov eax, 4         ; SYS_write
	//   BB 01 00 00 00         mov ebx, 1         ; stdout
	//   B9 00 81 04 08         mov ecx, 0x08048100; buf
	//   BA 01 00 00 00         mov edx, 1         ; len
	//   CD 80                  int 0x80
	//   B8 01 00 00 00         mov eax, 1         ; SYS_exit
	//   BB 2A 00 00 00         mov ebx, 42        ; status
	//   CD 80                  int 0x80
	initialProgram := []byte{
		0xB8, 0x04, 0x00, 0x00, 0x00,
		0xBB, 0x01, 0x00, 0x00, 0x00,
		0xB9, 0x00, 0x81, 0x04, 0x08,
		0xBA, 0x01, 0x00, 0x00, 0x00,
		0xCD, 0x80,
		0xB8, 0x01, 0x00, 0x00, 0x00,
		0xBB, 0x2A, 0x00, 0x00, 0x00,
		0xCD, 0x80,
	}
	if err := r.WriteCode(entry, initialProgram); err != nil {
		t.Fatalf("WriteCode (initial): %v", err)
	}
	if err := r.WriteCode(aAddr, []byte("A")); err != nil {
		t.Fatalf("WriteCode (data): %v", err)
	}

	events := r.Run(entry, 0x701FFFF0)

	// Receive the first event (write → Stdout).
	first := <-events
	if want := (proto.Stdout{Bytes: []byte("A")}); !reflect.DeepEqual(first, want) {
		t.Fatalf("first event: got %#v want %#v", first, want)
	}

	// Mid-session streaming write. The child is now between syscalls
	// (write has returned to the bridge, exit hasn't yet hit the next
	// PTRACE_SYSEMU stop).
	streamed := []byte{0x90, 0x90, 0x90, 0x90} // four NOPs — content doesn't matter
	if err := r.WriteCode(lateAddr, streamed); err != nil {
		t.Fatalf("WriteCode mid-session: %v", err)
	}

	// Drain the remaining events; expect Exit{42}.
	var rest []proto.Outbound
	for ev := range events {
		rest = append(rest, ev)
	}
	wantRest := []proto.Outbound{proto.Exit{Code: 42}}
	if !reflect.DeepEqual(rest, wantRest) {
		t.Errorf("remaining events: got %#v want %#v", rest, wantRest)
	}
}
