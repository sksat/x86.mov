//go:build linux

package runner

import (
	"runtime"
	"testing"
	"time"

	"github.com/sksat/x86.mov/turbo86/proto"
	"github.com/sksat/x86.mov/turbo86/stub"
)

// byteAt returns the byte a sparse MemRegion set holds at addr, plus
// whether any region covered it.
func byteAt(regions []proto.MemRegion, addr uint32) (byte, bool) {
	for _, r := range regions {
		if addr >= r.Addr && addr < r.Addr+uint32(len(r.Bytes)) {
			return r.Bytes[addr-r.Addr], true
		}
	}
	return 0, false
}

// TestRunner_FinalMemUpdate_BeforeExit pins the session-end frame flush:
// a MemUpdate-enabled session must emit one last MemUpdate carrying the
// guest's final memory *immediately before* the terminal Exit, so a
// progressive-display consumer (the explorer canvas) sees the last paint
// even when the periodic ticker is up to one interval stale.
//
// The interval is set huge (5s) so the periodic ticker can't fire before
// the guest exits in microseconds — any MemUpdate observed is therefore
// the end-of-session flush, not a tick.
//
// Guest: paint 0x42 at 0x08048100 (inside the RWX code region), then
// CALL_EXIT(0) via the mov-only ABI:
//
//	B0 42                 mov al, 0x42
//	A2 00 81 04 08        mov [0x08048100], al
//	B8 00 00 00 00        mov eax, 0
//	A3 FE 00 FE 1F        mov [0x1FFE00FE], eax   ; CALL_EXIT
func TestRunner_FinalMemUpdate_BeforeExit(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const entry uint32 = 0x08048000
	const paintAddr uint32 = 0x08048100
	code := []byte{
		0xB0, 0x42,
		0xA2, 0x00, 0x81, 0x04, 0x08,
		0xB8, 0x00, 0x00, 0x00, 0x00,
		0xA3, 0xFE, 0x00, 0xFE, 0x1F,
	}

	r, err := New(stub.Bytes)
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	if err := r.WriteCode(entry, code); err != nil {
		_ = r.Close()
		t.Fatalf("WriteCode: %v", err)
	}

	events := r.RunWithModeAndMemUpdate(
		entry, testStackTop, proto.ModeHost, 5*time.Second,
	)

	var got []proto.Outbound
	for ev := range events {
		got = append(got, ev)
	}

	// Expect exactly [MemUpdate{final frame}, Exit{0}].
	if len(got) != 2 {
		t.Fatalf("events: got %#v, want [MemUpdate, Exit]", got)
	}
	mu, ok := got[0].(proto.MemUpdate)
	if !ok {
		t.Fatalf("first event = %T, want MemUpdate (final frame before Exit)", got[0])
	}
	if ex, ok := got[1].(proto.Exit); !ok || ex.Code != 0 {
		t.Fatalf("second event = %#v, want Exit{Code:0}", got[1])
	}
	if b, present := byteAt(mu.Regions, paintAddr); !present || b != 0x42 {
		t.Errorf("final MemUpdate missing painted byte 0x42 at %#x (got %#x, present=%v)",
			paintAddr, b, present)
	}
}

// TestRunner_FinalMemUpdate_DisabledStaysSilent keeps the opt-in honest:
// a session that never enabled MemUpdate (interval 0 — the RunOnce /
// RunWithMode path) must NOT grow a trailing MemUpdate at exit, so the
// exact event-sequence goldens in abi_test.go etc. keep holding.
//
// Same guest as above (paint + CALL_EXIT), run without an interval.
func TestRunner_FinalMemUpdate_DisabledStaysSilent(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const entry uint32 = 0x08048000
	code := []byte{
		0xB0, 0x42,
		0xA2, 0x00, 0x81, 0x04, 0x08,
		0xB8, 0x00, 0x00, 0x00, 0x00,
		0xA3, 0xFE, 0x00, 0xFE, 0x1F,
	}

	events, err := RunOnce(stub.Bytes, map[uint32][]byte{entry: code}, entry, testStackTop)
	if err != nil {
		t.Fatalf("RunOnce: %v", err)
	}
	want := []proto.Outbound{proto.Exit{Code: 0}}
	if len(events) != len(want) {
		t.Fatalf("events: got %#v, want %#v", events, want)
	}
	if ex, ok := events[0].(proto.Exit); !ok || ex.Code != 0 {
		t.Fatalf("event = %#v, want Exit{Code:0} (no trailing MemUpdate)", events[0])
	}
}
