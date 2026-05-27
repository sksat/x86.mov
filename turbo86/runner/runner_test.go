//go:build linux

package runner

import (
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
