//go:build linux

package runner

import (
	"reflect"
	"runtime"
	"testing"

	"github.com/sksat/x86.mov/turbo86/proto"
	"github.com/sksat/x86.mov/turbo86/stub"
)

// TestLoadElf_MmapAfterTrampolineClobber is the regression test for the
// real SIMD86 deck boot failure: the loader faulted with
//
//	apply ELF plan: mmap ELF segment ...: inject: expected syscall-stop, got signal 4
//
// (signal 4 = SIGILL). Root cause was ORDERING. applyElfPlan used to map
// and write each PT_LOAD in one interleaved pass. The deck's PT_LOADs are
// (in file order) .text, then a ~160 MiB read-only .rodata that starts
// inside the static arena and runs past the trampoline page 0x09040000,
// then a .bss segment ABOVE the arena. Writing .rodata clobbered the
// trampoline's `CD 80`; the very next segment (.bss, out-of-arena) then
// needed an injectSyscall mmap, which jumped onto the overwritten bytes
// and SIGILL'd.
//
// The fix splits applyElfPlan into two phases — map every out-of-arena
// segment FIRST (trampoline still intact), then write all bytes — so a
// post-write segment never needs an inject. This test reproduces the
// exact hazard with a tiny synthetic ELF:
//
//   - entry code (in-arena) reads a byte from an out-of-arena data
//     segment and exits with it;
//   - an in-arena segment at the trampoline page 0x09040000 whose write
//     overwrites the trampoline with 0xCC (int3) — emitted BEFORE the
//     out-of-arena segment so the interleaved code would clobber-then-
//     inject;
//   - the out-of-arena data segment holding exit code 42, which forces a
//     load-time mmap (the inject that the clobber used to break).
//
// Interleaved (old) → SIGILL fault. Two-phase (fixed) → Exit{42}.
func TestLoadElf_MmapAfterTrampolineClobber(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const (
		entry    uint32 = 0x08048000
		trampSeg uint32 = trapTrampolineAddr // 0x09040000, inside the arena
		dataSeg  uint32 = 0x10000000         // out-of-arena → needs an mmap
	)

	// entry: al = [dataSeg]; ABI exit(al). The address is written as
	// literal little-endian bytes (dataSeg = 0x10000000) — a byte() of the
	// typed const would be a constant conversion that overflows byte.
	//   A0 00 00 00 10   mov al, [0x10000000]
	//   A2 FE 00 FE 1F   mov [0x1FFE00FE], al
	code := []byte{
		0xA0, 0x00, 0x00, 0x00, 0x10,
		0xA2, 0xFE, 0x00, 0xFE, 0x1F,
	}
	// In-arena segment that overwrites the 7 trampoline bytes with int3.
	tramp := []byte{0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC}

	// Order matters: the trampoline-clobbering in-arena segment is emitted
	// BEFORE the out-of-arena one, so an interleaved loader writes the
	// clobber and then injects an mmap for dataSeg — the failure path.
	img := buildElf32(entry, []elfSeg{
		{vaddr: entry, data: code, memsz: uint32(len(code))},
		{vaddr: trampSeg, data: tramp, memsz: uint32(len(tramp))},
		{vaddr: dataSeg, data: []byte{42}, memsz: 1},
	})

	r, err := New(stub.Bytes)
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	defer r.Close()

	if err := r.LoadElf(img, proto.ModeHost, 0, nil); err != nil {
		t.Fatalf("LoadElf: %v", err)
	}
	var events []proto.Outbound
	for ev := range r.Run(entry, testStackTop) {
		events = append(events, ev)
	}
	want := []proto.Outbound{proto.Exit{Code: 42}}
	if !reflect.DeepEqual(events, want) {
		t.Errorf("two-phase ordering regression (trampoline clobbered before a later mmap):\n  got:  %#v\n  want: %#v",
			events, want)
	}
}
