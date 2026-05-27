//go:build linux

package runner

import (
	"encoding/binary"
	"reflect"
	"runtime"
	"testing"

	"github.com/sksat/x86.mov/turbo86/proto"
	"github.com/sksat/x86.mov/turbo86/stub"
)

func binaryLittleEndianPut(b []byte, v uint32) {
	binary.LittleEndian.PutUint32(b, v)
}

// TestRunner_SigactionForwardsSIGILLToGuestHandler exercises the full
// signal-passthrough path:
//
//  1. rt_sigaction(SIGILL, &kact, NULL, 8) installs the guest's SIGILL
//     handler natively in the child via the syscall passthrough path.
//  2. ud2 raises SIGILL.
//  3. The runner sees the signal stop, forwards it via PTRACE_SYSCALL
//     with sig=SIGILL.
//  4. The kernel dispatches into the guest's handler (constructed
//     sigframe + EIP = handler_addr).
//  5. The handler runs `mov eax,1; mov ebx,99; int 0x80` → bridge
//     emits Exit{99} and the session ends.
//
// This proves the movfuscator dispatch pattern (sigaction-registered
// trap handler invoked by the kernel) actually works on turbo86.
func TestRunner_SigactionForwardsSIGILLToGuestHandler(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const (
		entry         uint32 = 0x08048000
		handlerAddr   uint32 = 0x08048100
		restorerAddr  uint32 = 0x08048200
		kactStructPtr uint32 = 0x08048080
	)

	// k_sigaction (i386, NR_rt_sigaction layout): 20 bytes total.
	//   off 0:  sa_handler   = handlerAddr
	//   off 4:  sa_flags     = SA_RESTORER (0x04000000)
	//   off 8:  sa_restorer  = restorerAddr
	//   off 12: sa_mask[0]   = 0
	//   off 16: sa_mask[1]   = 0
	const saRestorer uint32 = 0x04000000
	kact := make([]byte, 20)
	binaryLittleEndianPut(kact[0:4], handlerAddr)
	binaryLittleEndianPut(kact[4:8], saRestorer)
	binaryLittleEndianPut(kact[8:12], restorerAddr)
	// sa_mask is left zero

	// Main code at `entry`: rt_sigaction(SIGILL=4, &kact, NULL, 8), then ud2.
	//   B8 AE 00 00 00         mov eax, 174   (rt_sigaction)
	//   BB 04 00 00 00         mov ebx, 4     (SIGILL)
	//   B9 80 80 04 08         mov ecx, 0x08048080  (&kact)
	//   BA 00 00 00 00         mov edx, 0
	//   BE 08 00 00 00         mov esi, 8
	//   CD 80                  int 0x80
	//   0F 0B                  ud2            (raise SIGILL)
	mainProgram := []byte{
		0xB8, 0xAE, 0x00, 0x00, 0x00,
		0xBB, 0x04, 0x00, 0x00, 0x00,
		0xB9, 0x80, 0x80, 0x04, 0x08,
		0xBA, 0x00, 0x00, 0x00, 0x00,
		0xBE, 0x08, 0x00, 0x00, 0x00,
		0xCD, 0x80,
		0x0F, 0x0B,
	}

	// SIGILL handler at `handlerAddr`: exit(99).
	//   B8 01 00 00 00         mov eax, 1
	//   BB 63 00 00 00         mov ebx, 99
	//   CD 80                  int 0x80
	handler := []byte{
		0xB8, 0x01, 0x00, 0x00, 0x00,
		0xBB, 0x63, 0x00, 0x00, 0x00,
		0xCD, 0x80,
	}

	// sa_restorer trampoline at `restorerAddr`: rt_sigreturn.
	// Never executed in this test (handler exits), but the kernel
	// stores it as the post-handler return address; providing a valid
	// page-mapped pointer keeps SA_RESTORER honest.
	//   B8 AD 00 00 00         mov eax, 173   (rt_sigreturn)
	//   CD 80                  int 0x80
	restorer := []byte{
		0xB8, 0xAD, 0x00, 0x00, 0x00,
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
		{entry, mainProgram},
		{handlerAddr, handler},
		{restorerAddr, restorer},
		{kactStructPtr, kact},
	} {
		if err := r.WriteCode(w.addr, w.bytes); err != nil {
			t.Fatalf("WriteCode 0x%x: %v", w.addr, err)
		}
	}

	events := r.Run(entry, 0x701FFFF0)
	got, _ := collectEvents(events)
	want := []proto.Outbound{proto.Exit{Code: 99}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("events:\n  got:  %#v\n  want: %#v", got, want)
	}
}
