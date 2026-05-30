//go:build linux

package runner

import (
	"runtime"
	"testing"

	"github.com/sksat/x86.mov/turbo86/proto"
	"github.com/sksat/x86.mov/turbo86/stub"
)

// TestLoadElf_MemUpdateHonorsWatchRegions proves the periodic MemUpdate
// snapshot, when the session declared a watchRegions set, restricts
// itself to ONLY the watched range and never re-streams non-zero pages
// that live outside it.
//
// This is the large-deck doctrine in miniature: a SIMD86 deck bakes
// ~160 MiB of immutable slide pixels into read-only .rodata that never
// changes; only the framebuffer page actually mutates frame-to-frame.
// The frontend watches just the FB range, and the snapshot MUST NOT
// re-emit the whole deck every interval. Here we stand in for "the
// deck" with two distinct non-zero markers inside the static arena:
//
//   - an IN-WATCH marker at 0x08050000 (the stand-in framebuffer page),
//   - an OUT-OF-WATCH marker at 0x08060000 (stand-in for the immutable
//     .rodata the watch set must exclude).
//
// The guest also occupies its own code page at 0x08048000 — another
// non-zero, out-of-watch page a full scan would happily emit. With the
// watch set = just the FB page, every emitted MemRegion.Addr must fall
// inside [0x08050000, 0x08051000) and the out-of-watch marker address
// must never appear in any MemUpdate.
//
// Guest (runs on the real CPU between syscall stops, so a plain
// dec/jnz delay loop is fine — only the ABI exit is the mov form):
//
//	B0 5A             mov al, 0x5A
//	A2 00 00 05 08    mov [0x08050000], al    ; in-watch marker (FB page)
//	B0 7E             mov al, 0x7E
//	A2 00 00 06 08    mov [0x08060000], al    ; out-of-watch marker (.rodata)
//	B9 00 00 00 10    mov ecx, 0x10000000     ; delay so ticks fire
//	49                dec ecx                  ; loop:
//	75 FD             jnz loop
//	B8 00 00 00 00    mov eax, 0
//	A3 FE 00 FE 1F    mov [0x1FFE00FE], eax    ; ABI exit(0)
func TestLoadElf_MemUpdateHonorsWatchRegions(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const (
		entry            uint32 = 0x08048000
		inWatchMarker    uint32 = 0x08050000
		outOfWatchMark   uint32 = 0x08060000
		watchPageStart   uint32 = 0x08050000
		watchPageEnd     uint32 = 0x08051000
		memUpdateEveryMs        = 5
	)

	code := []byte{
		0xB0, 0x5A, // mov al, 0x5A
		0xA2, 0x00, 0x00, 0x05, 0x08, // mov [0x08050000], al
		0xB0, 0x7E, // mov al, 0x7E
		0xA2, 0x00, 0x00, 0x06, 0x08, // mov [0x08060000], al
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

	watch := []proto.WatchRegion{{Addr: watchPageStart, Size: 0x1000}}
	if err := r.LoadElf(img, proto.ModeHost, memUpdateEveryMs, watch); err != nil {
		t.Fatalf("LoadElf: %v", err)
	}

	var events []proto.Outbound
	for ev := range r.Run(entry, testStackTop) {
		events = append(events, ev)
	}

	// Session must end cleanly with the guest's exit(0).
	if len(events) == 0 {
		t.Fatalf("no events at all")
	}
	if _, ok := events[len(events)-1].(proto.Exit); !ok {
		t.Fatalf("last event not Exit: got %#v", events[len(events)-1])
	}

	var memUpdates int
	var sawInWatch bool
	for _, ev := range events {
		mu, ok := ev.(proto.MemUpdate)
		if !ok {
			continue
		}
		memUpdates++
		for _, reg := range mu.Regions {
			end := reg.Addr + uint32(len(reg.Bytes))
			// Every emitted region must lie fully inside the watch page.
			if reg.Addr < watchPageStart || end > watchPageEnd {
				t.Errorf("MemUpdate region [0x%x, 0x%x) escapes watch range [0x%x, 0x%x)",
					reg.Addr, end, watchPageStart, watchPageEnd)
			}
			// The out-of-watch marker page must never be streamed.
			if reg.Addr <= outOfWatchMark && outOfWatchMark < end {
				t.Errorf("MemUpdate streamed out-of-watch marker page 0x%x (region [0x%x, 0x%x))",
					outOfWatchMark, reg.Addr, end)
			}
			// The guest code page is also out-of-watch; it must not appear.
			if reg.Addr <= entry && entry < end {
				t.Errorf("MemUpdate streamed out-of-watch code page 0x%x (region [0x%x, 0x%x))",
					entry, reg.Addr, end)
			}
			if reg.Addr <= inWatchMarker && inWatchMarker < end {
				sawInWatch = true
			}
		}
	}
	if memUpdates == 0 {
		t.Fatalf("expected >=1 MemUpdate, got 0 (events=%#v)", events)
	}
	if !sawInWatch {
		t.Errorf("expected the in-watch marker at 0x%x to appear in some MemUpdate, never saw it", inWatchMarker)
	}
}
