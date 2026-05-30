//go:build linux

package runner

import (
	"reflect"
	"runtime"
	"testing"

	"github.com/sksat/x86.mov/turbo86/proto"
	"github.com/sksat/x86.mov/turbo86/stub"
)

// TestLoadElf_TrampolineSurvivesOverlappingSegment_HostMode is the
// real-deck bug check: the runtime ABI mmap_request relies on the
// int-0x80 site inside the trap restorer trampoline at
// trapTrampolineAddr (0x09040000) — and that address lives INSIDE the
// stub's static 16 MiB arena [0x08048000, 0x09048000). The real SIMD86
// deck has a ~160 MiB read-only .rodata; a PT_LOAD segment can easily
// span 0x09040000. tracerLoop installs the trampoline BEFORE applying
// the ELF plan, so if a segment overlapping 0x09040000 is written after,
// it clobbers the trampoline. Any later injectSyscall (e.g. the deck's
// own runtime framebuffer mmap_request) then jumps onto the segment's
// bytes instead of `CD 80` and faults.
//
// This test reproduces exactly that in HOST mode:
//
//   - a code PT_LOAD at 0x08048000 that, at runtime, issues a mov-only
//     ABI mmap_request for a fresh page at 0x00200000, writes a marker
//     byte there, then exit(42) — so it exercises injectSyscall AFTER
//     the load completes;
//   - a data PT_LOAD at 0x09038000 spanning [0x09038000, 0x09048000),
//     which COVERS the trampoline page 0x09040000, filled with 0xCC
//     (non-zero; 0xCC is int3, so an injectSyscall that lands here traps
//     instead of issuing a clean syscall).
//
// If the loader leaves the trampoline clobbered, the runtime
// mmap_request's injectSyscall fails and the session ends in Fault
// rather than the clean Exit{42} the guest asks for. The loader must
// keep the trampoline intact (e.g. re-install it after writing all
// PT_LOAD segments).
func TestLoadElf_TrampolineSurvivesOverlappingSegment_HostMode(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const (
		entry    uint32 = 0x08048000
		fbAddr   uint32 = 0x00200000
		dataAddr uint32 = 0x09038000
	)

	// Code: mmap a fresh FB page via the mov-only ABI, mark it, exit(42).
	//   B8 00 00 20 00    mov eax, 0x00200000   ; addr=0x00200000, pages=1
	//   A3 20 00 FE 1F    mov [0x1FFE0020], eax ; ABI mmap_request
	//   B0 42             mov al, 0x42
	//   A2 00 00 20 00    mov [0x00200000], al  ; write marker into new page
	//   B8 2A 00 00 00    mov eax, 42
	//   A3 FE 00 FE 1F    mov [0x1FFE00FE], eax ; ABI exit(42)
	code := []byte{
		0xB8, 0x00, 0x00, 0x20, 0x00,
		0xA3, 0x20, 0x00, 0xFE, 0x1F,
		0xB0, 0x42,
		0xA2, 0x00, 0x00, 0x20, 0x00,
		0xB8, 0x2A, 0x00, 0x00, 0x00,
		0xA3, 0xFE, 0x00, 0xFE, 0x1F,
	}

	// Data segment covering [0x09038000, 0x09048000) — spans the
	// trampoline page 0x09040000 — filled with non-zero 0xCC bytes.
	const dataLen = 0x10000 // 64 KiB: 0x09038000..0x09048000
	data := make([]byte, dataLen)
	for i := range data {
		data[i] = 0xCC
	}

	img := buildElf32(entry, []elfSeg{
		{vaddr: entry, data: code, memsz: uint32(len(code))},
		{vaddr: dataAddr, data: data, memsz: uint32(len(data))},
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
		t.Errorf("trampoline did not survive an overlapping host-mode segment:\n  got:  %#v\n  want: %#v",
			events, want)
	}
}
