//go:build linux

package runner

import (
	"reflect"
	"runtime"
	"testing"

	"github.com/sksat/x86.mov/turbo86/proto"
	"github.com/sksat/x86.mov/turbo86/stub"
)

// TestLoadElf_OverlappingSegmentsDoNotZeroEachOther guards against the
// MAP_FIXED zero-wipe: when two out-of-arena PT_LOAD segments share a
// page, mmapping the second segment's page range wholesale (MAP_FIXED,
// anonymous, demand-zero) re-maps the page the FIRST segment already
// wrote, wiping its bytes. The loader must mmap only the pages not
// already mapped (mapSegmentGaps), so a page populated by an earlier
// segment survives.
//
// Both data segments live in the same out-of-arena page 0x10000000:
//   - segment A: vaddr 0x10000000, byte 0xAA.
//   - segment B: vaddr 0x10000800, byte 0x2A (42).
//
// Code (in-arena) reads A's byte; if it's still 0xAA (not zeroed by B's
// mapping) it exits with B's byte (42), else exits 1:
//
//	A0 00 00 00 10   mov al, [0x10000000]   ; A's byte (want 0xAA)
//	3C AA            cmp al, 0xAA
//	75 0A            jne fail               ; +10 → exit(1)
//	A0 00 08 00 10   mov al, [0x10000800]   ; B's byte (42)
//	A2 FE 00 FE 1F   mov [0x1FFE00FE], al   ; exit(al)
//	B0 01            mov al, 1              ; fail:
//	A2 FE 00 FE 1F   mov [0x1FFE00FE], al   ; exit(1)
//
// Naive whole-range mmap → A's 0xAA gets zeroed by B's MAP_FIXED → exit(1)
// (RED). Gap-only mmap → A survives → exit(42) (GREEN).
func TestLoadElf_OverlappingSegmentsDoNotZeroEachOther(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const (
		entry uint32 = 0x08048000
		segA  uint32 = 0x10000000
		segB  uint32 = 0x10000800
	)

	code := []byte{
		0xA0, 0x00, 0x00, 0x00, 0x10, // mov al, [0x10000000]
		0x3C, 0xAA, // cmp al, 0xAA
		0x75, 0x0A, // jne +10 (fail)
		0xA0, 0x00, 0x08, 0x00, 0x10, // mov al, [0x10000800]
		0xA2, 0xFE, 0x00, 0xFE, 0x1F, // mov [0x1FFE00FE], al  exit(al)
		0xB0, 0x01, // fail: mov al, 1
		0xA2, 0xFE, 0x00, 0xFE, 0x1F, // mov [0x1FFE00FE], al  exit(1)
	}

	img := buildElf32(entry, []elfSeg{
		{vaddr: entry, data: code, memsz: uint32(len(code))},
		{vaddr: segA, data: []byte{0xAA}, memsz: 1},
		{vaddr: segB, data: []byte{0x2A}, memsz: 1},
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
		t.Errorf("overlapping segments corrupted each other:\n  got:  %#v\n  want: %#v",
			events, want)
	}
}
