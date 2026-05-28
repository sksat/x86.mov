//go:build linux

package runner

import (
	"reflect"
	"runtime"
	"testing"

	"github.com/sksat/x86.mov/turbo86/proto"
	"github.com/sksat/x86.mov/turbo86/stub"
)

// TestRunner_SigactionOldactReturnsPrevious exercises the oldact-write
// path: install one handler, then call sigaction again with a different
// handler AND a non-NULL oldact. The kernel (host mode) / trap-mode
// emulation must fill oldact's sa_handler with the *previous* address.
// The guest reads oldact's first 4 bytes and exits with the low byte
// of that value, so the Exit code directly reports what oldact held.
//
// Runs in both modes — they should agree, per the migration-parity
// doctrine. This is the bug codex P2 flagged: trap mode used to drop
// oldact writes silently, which would have shown up here as Exit{0}
// instead of Exit{0x42}.
func TestRunner_SigactionOldactReturnsPrevious(t *testing.T) {
	for _, mode := range []proto.Mode{proto.ModeHost, proto.ModeTrap} {
		t.Run(string(mode), func(t *testing.T) {
			runSigactionOldactTest(t, mode)
		})
	}
}

func runSigactionOldactTest(t *testing.T, mode proto.Mode) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const (
		entry      uint32 = 0x08048000
		actAAddr   uint32 = 0x08048080 // first k_sigaction (handler 0x42)
		actBAddr   uint32 = 0x08048100 // second k_sigaction (handler 0x99)
		oldactAddr uint32 = 0x08048300 // oldact write target

		handlerASentinel = byte(0x42)
		handlerBSentinel = byte(0x99)
	)

	// Pre-populated structs: only sa_handler (offset 0) matters; the
	// rest of the 140-byte userspace layout stays zero (the stub's
	// anonymous mmap'd region is demand-zero).
	actA := []byte{handlerASentinel, 0, 0, 0}
	actB := []byte{handlerBSentinel, 0, 0, 0}

	// Guest program:
	//   sigaction(SIGUSR1=10, actA, NULL, 8)
	//   sigaction(SIGUSR1=10, actB, &oldact, 8)
	//   ebx = *(uint32 *)oldact       ; should be handler-A sentinel
	//   exit(ebx)
	//
	//   B8 AE 00 00 00         mov eax, 174
	//   BB 0A 00 00 00         mov ebx, 10
	//   B9 80 80 04 08         mov ecx, actAAddr
	//   BA 00 00 00 00         mov edx, NULL
	//   BE 08 00 00 00         mov esi, 8
	//   CD 80                  int 0x80
	//   B8 AE 00 00 00         mov eax, 174
	//   BB 0A 00 00 00         mov ebx, 10
	//   B9 00 81 04 08         mov ecx, actBAddr
	//   BA 00 83 04 08         mov edx, oldactAddr
	//   BE 08 00 00 00         mov esi, 8
	//   CD 80                  int 0x80
	//   8B 1D 00 83 04 08      mov ebx, DWORD PTR ds:0x08048300
	//   B8 01 00 00 00         mov eax, 1
	//   CD 80                  int 0x80
	program := []byte{
		0xB8, 0xAE, 0x00, 0x00, 0x00,
		0xBB, 0x0A, 0x00, 0x00, 0x00,
		0xB9, 0x80, 0x80, 0x04, 0x08,
		0xBA, 0x00, 0x00, 0x00, 0x00,
		0xBE, 0x08, 0x00, 0x00, 0x00,
		0xCD, 0x80,
		0xB8, 0xAE, 0x00, 0x00, 0x00,
		0xBB, 0x0A, 0x00, 0x00, 0x00,
		0xB9, 0x00, 0x81, 0x04, 0x08,
		0xBA, 0x00, 0x83, 0x04, 0x08,
		0xBE, 0x08, 0x00, 0x00, 0x00,
		0xCD, 0x80,
		0x8B, 0x1D, 0x00, 0x83, 0x04, 0x08,
		0xB8, 0x01, 0x00, 0x00, 0x00,
		0xCD, 0x80,
	}

	r, err := New(stub.Bytes)
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	defer r.Close()

	for _, w := range []struct {
		addr  uint32
		bytes []byte
	}{
		{entry, program},
		{actAAddr, actA},
		{actBAddr, actB},
	} {
		if err := r.WriteCode(w.addr, w.bytes); err != nil {
			t.Fatalf("WriteCode 0x%x: %v", w.addr, err)
		}
	}

	events := r.RunWithMode(entry, 0x701FFFF0, mode)
	got, _ := collectEvents(events)
	want := []proto.Outbound{proto.Exit{Code: int32(handlerASentinel)}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("events (%s mode):\n  got:  %#v\n  want: %#v", mode, got, want)
	}
}
