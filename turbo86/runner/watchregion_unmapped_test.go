//go:build linux

package runner

import (
	"runtime"
	"testing"

	"github.com/sksat/x86.mov/turbo86/proto"
	"github.com/sksat/x86.mov/turbo86/stub"
)

// TestLoadElf_WatchRegionUnmappedDoesNotFault guards the real-deck boost
// case the frontend actually produces: makeLoadElfMessage watches EVERY
// known framebuffer mode address, but a deck only mmaps the FB(s) it
// uses, so most watch ranges point at unmapped guest memory. A naive
// per-range snapshot walk reads /proc/PID/mem over the whole watch range
// and short-reads on the unmapped pages, which would surface as a fault
// and kill the boost session mid-run.
//
// Here the watch set mixes one mapped range (a page inside the static
// arena, where the guest writes a marker) with one wholly-unmapped range
// (0x40000000, never mmap'd). The session MUST still end with the guest's
// clean Exit — never a Fault — and the unmapped address must never appear
// in a MemUpdate.
//
// Guest (delay loop runs on the real CPU between syscall stops):
//
//	B0 5A             mov al, 0x5A
//	A2 00 00 05 08    mov [0x08050000], al    ; marker in a mapped arena page
//	B9 00 00 00 10    mov ecx, 0x10000000     ; delay so ticks fire
//	49                dec ecx                  ; loop:
//	75 FD             jnz loop
//	B8 00 00 00 00    mov eax, 0
//	A3 FE 00 FE 1F    mov [0x1FFE00FE], eax    ; ABI exit(0)
func TestLoadElf_WatchRegionUnmappedDoesNotFault(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const (
		entry            uint32 = 0x08048000
		mappedMarker     uint32 = 0x08050000
		unmappedWatch    uint32 = 0x40000000
		memUpdateEveryMs        = 5
	)

	code := []byte{
		0xB0, 0x5A, // mov al, 0x5A
		0xA2, 0x00, 0x00, 0x05, 0x08, // mov [0x08050000], al
		0xB9, 0x00, 0x00, 0x00, 0x10, // mov ecx, 0x10000000
		0x49,       // dec ecx          ; loop:
		0x75, 0xFD, // jnz loop
		0xB8, 0x00, 0x00, 0x00, 0x00, // mov eax, 0
		0xA3, 0xFE, 0x00, 0xFE, 0x1F, // mov [0x1FFE00FE], eax  ABI exit(0)
	}
	img := buildElf32(entry, []elfSeg{
		{vaddr: entry, data: code, memsz: uint32(len(code))},
	})

	r, err := New(stub.Bytes)
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	defer r.Close()

	// One mapped watch page (the arena) + one unmapped watch page.
	watch := []proto.WatchRegion{
		{Addr: mappedMarker, Size: 0x1000},
		{Addr: unmappedWatch, Size: 0x1000},
	}
	if err := r.LoadElf(img, proto.ModeHost, memUpdateEveryMs, watch); err != nil {
		t.Fatalf("LoadElf: %v", err)
	}

	var events []proto.Outbound
	for ev := range r.Run(entry, testStackTop) {
		events = append(events, ev)
	}

	if len(events) == 0 {
		t.Fatalf("no events at all")
	}
	for _, ev := range events {
		if f, ok := ev.(proto.Fault); ok {
			t.Fatalf("session faulted (the unmapped watch range was not tolerated): %q", f.Reason)
		}
		if mu, ok := ev.(proto.MemUpdate); ok {
			for _, reg := range mu.Regions {
				end := reg.Addr + uint32(len(reg.Bytes))
				if reg.Addr < unmappedWatch+0x1000 && unmappedWatch < end {
					t.Errorf("MemUpdate streamed the unmapped watch page 0x%x (region [0x%x, 0x%x))",
						unmappedWatch, reg.Addr, end)
				}
			}
		}
	}
	if _, ok := events[len(events)-1].(proto.Exit); !ok {
		t.Fatalf("last event not Exit: got %#v", events[len(events)-1])
	}
}
