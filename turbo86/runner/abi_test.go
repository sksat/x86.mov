//go:build linux

package runner

import (
	"reflect"
	"runtime"
	"testing"

	"github.com/sksat/x86.mov/turbo86/proto"
	"github.com/sksat/x86.mov/turbo86/stub"
)

// TestRunOnce_AbiSetVideoMode is the headline mov-only ABI test: the
// guest selects a VGA video mode without `int 0x10` by writing the
// mode byte to a magic address on the runner's ABI page. The runner
// catches the SIGSEGV that the unmapped write produces, decodes the
// faulting `mov [imm32], al`, emits Outbound{VideoMode{Mode: 0x13}},
// advances EIP past the 5-byte mov, and resumes — same flow turbo86
// will use for canvas_mandelbrot once the stubs are switched off the
// BIOS `int 0x10` convention.
//
// Guest:
//
//	B0 13                   mov al, 0x13         ; (2 bytes)
//	A2 10 00 FE 1F          mov [0x1FFE0010], al ; (5 bytes) — ABI set_video_mode
//	B8 01 00 00 00          mov eax, 1           ; SYS_exit
//	BB 00 00 00 00          mov ebx, 0           ; status = 0
//	CD 80                   int 0x80             ; exit(0)
func TestRunOnce_AbiSetVideoMode(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const entry uint32 = 0x08048000
	code := []byte{
		0xB0, 0x13,
		0xA2, 0x10, 0x00, 0xFE, 0x1F,
		0xB8, 0x01, 0x00, 0x00, 0x00,
		0xBB, 0x00, 0x00, 0x00, 0x00,
		0xCD, 0x80,
	}

	events, err := RunOnce(stub.Bytes, map[uint32][]byte{entry: code}, entry, testStackTop)
	if err != nil {
		t.Fatalf("RunOnce: %v", err)
	}
	want := []proto.Outbound{
		proto.VideoMode{Mode: 0x13},
		proto.Exit{Code: 0},
	}
	if !reflect.DeepEqual(events, want) {
		t.Errorf("events:\n  got:  %#v\n  want: %#v", events, want)
	}
}

// TestRunOnce_AbiSetVideoMode_TrapMode pins the two-mode parity
// doctrine: the mov-only ABI dispatch must produce the same event
// stream under proto.ModeTrap as under proto.ModeHost. The runner
// owns the SIGSEGV interception regardless of which signal-dispatch
// mode it's running, so the guest sees identical behaviour either
// way — this is the mov-only ABI's equivalent of the sigaction
// parity tests.
func TestRunOnce_AbiSetVideoMode_TrapMode(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const entry uint32 = 0x08048000
	code := []byte{
		0xB0, 0x13,
		0xA2, 0x10, 0x00, 0xFE, 0x1F,
		0xB8, 0x01, 0x00, 0x00, 0x00,
		0xBB, 0x00, 0x00, 0x00, 0x00,
		0xCD, 0x80,
	}

	r, err := New(stub.Bytes)
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	defer r.Close()
	if err := r.WriteCode(entry, code); err != nil {
		t.Fatalf("WriteCode: %v", err)
	}
	ch := r.RunWithContextAndMode(proto.Context{
		Regs: proto.Regs{Eip: entry, Esp: testStackTop},
	}, proto.ModeTrap)
	var events []proto.Outbound
	for ev := range ch {
		events = append(events, ev)
	}
	want := []proto.Outbound{
		proto.VideoMode{Mode: 0x13},
		proto.Exit{Code: 0},
	}
	if !reflect.DeepEqual(events, want) {
		t.Errorf("events:\n  got:  %#v\n  want: %#v", events, want)
	}
}
