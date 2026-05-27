//go:build linux

package runner

import (
	"reflect"
	"runtime"
	"testing"

	"github.com/sksat/x86.mov/turbo86/proto"
	"github.com/sksat/x86.mov/turbo86/stub"
)

// TestRunWithContext_ResumesFromMidState models the engine-migration
// path: another engine (movie86) ran far enough to set up syscall
// arguments in registers, then handed the state off via Context. turbo86
// loads the full reg file from Context.Regs (Eax = SYS_exit, Ebx = 42)
// and only the bare `int 0x80` instruction remains in guest memory.
// If Context loading is wired up correctly, the child exits with 42.
func TestRunWithContext_ResumesFromMidState(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const entry uint32 = 0x08048000
	ctx := proto.Context{
		Regs: proto.Regs{
			Eax: 1,  // SYS_exit, *not* set by guest code below — proves
			Ebx: 42, // and *not* set either — proves Ebx transferred.
			Esp: 0x701FFFF0,
			Eip: entry,
		},
		Regions: []proto.MemRegion{
			{Addr: entry, Bytes: []byte{0xCD, 0x80}}, // int 0x80
		},
	}

	events, err := RunWithContext(stub.Bytes, ctx)
	if err != nil {
		t.Fatalf("RunWithContext: %v", err)
	}
	want := []proto.Outbound{proto.Exit{Code: 42}}
	if !reflect.DeepEqual(events, want) {
		t.Errorf("events:\n  got:  %#v\n  want: %#v", events, want)
	}
}

// TestRunWithContext_TransfersAllGPRegs sanity-checks that *each* GP
// register in Context.Regs makes it into the child by having a guest
// program inspect them. The program copies ebx → memory, then exits
// with eax = 1, ebx as the status. The test seeds ebx via Context.Regs
// rather than via guest code, so a failure to load ebx surfaces as a
// mismatched exit code.
func TestRunWithContext_TransfersEbxIndependentlyOfCode(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const entry uint32 = 0x08048000
	// Code: just `mov eax, 1; int 0x80`. Ebx is NOT set by guest code.
	//   B8 01 00 00 00         mov eax, 1
	//   CD 80                  int 0x80
	code := []byte{0xB8, 0x01, 0x00, 0x00, 0x00, 0xCD, 0x80}

	ctx := proto.Context{
		Regs: proto.Regs{
			Ebx: 0x57, // exit status preloaded; if the loader drops Ebx, this fails.
			Esp: 0x701FFFF0,
			Eip: entry,
		},
		Regions: []proto.MemRegion{{Addr: entry, Bytes: code}},
	}

	events, err := RunWithContext(stub.Bytes, ctx)
	if err != nil {
		t.Fatalf("RunWithContext: %v", err)
	}
	want := []proto.Outbound{proto.Exit{Code: 0x57}}
	if !reflect.DeepEqual(events, want) {
		t.Errorf("events:\n  got:  %#v\n  want: %#v", events, want)
	}
}
