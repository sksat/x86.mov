//go:build linux

package runner

import (
	"runtime"
	"testing"
	"time"

	"github.com/sksat/x86.mov/turbo86/proto"
	"github.com/sksat/x86.mov/turbo86/stub"
)

// TestRunner_MemUpdateTicker_EmitsMidRun pins the periodic
// `proto.MemUpdate` cadence: with `RunWithModeAndMemUpdate(..., 50ms)`
// a guest stuck in a no-syscall tight loop should still produce a
// stream of MemUpdate events without ending the session. Without the
// ticker the same fixture (jmp short -2) sees zero events until
// something kills it.
func TestRunner_MemUpdateTicker_EmitsMidRun(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const entry uint32 = 0x08048000
	loop := []byte{0xEB, 0xFE} // jmp short -2, no syscalls

	r, err := New(stub.Bytes)
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	// Don't defer Close here — the eventsCh is unbuffered so Close
	// would deadlock if the tracer is mid-emit when we stop reading.
	// We Close + drain at the end of the test instead.

	if err := r.WriteCode(entry, loop); err != nil {
		t.Fatalf("WriteCode: %v", err)
	}

	events := r.RunWithModeAndMemUpdate(
		entry, 0x701FFFF0, proto.ModeHost, 50*time.Millisecond,
	)

	// 250ms gives ~5 ticks at 50ms cadence; back-pressure can drop
	// some so we require ≥ 2 to be robust against scheduling jitter.
	const want = 2
	deadline := time.After(2 * time.Second)
	var got int
loop_events:
	for got < want {
		select {
		case ev, ok := <-events:
			if !ok {
				t.Fatalf("events channel closed before %d MemUpdates (got %d)", want, got)
			}
			if _, isMemUpdate := ev.(proto.MemUpdate); isMemUpdate {
				got++
			} else {
				t.Logf("non-MemUpdate event during periodic ticker: %T %#v", ev, ev)
			}
		case <-deadline:
			break loop_events
		}
	}

	// Tear down: kick a draining goroutine first so the tracer can
	// finish its in-flight MemUpdate send (eventsCh is unbuffered),
	// then Close() — drain exits when eventsCh closes.
	done := make(chan struct{})
	go func() {
		for range events {
		}
		close(done)
	}()
	_ = r.Close()
	<-done

	if got < want {
		t.Errorf("got %d MemUpdate events in 2s, want ≥ %d", got, want)
	}
}

// TestRunner_MemUpdateZeroInterval_NoMemUpdate keeps the default
// behavior honest: when `memUpdateInterval == 0` (the existing Run /
// RunWithMode entry points), the session should never emit a
// MemUpdate. Catches a regression where the ticker would fire even
// without an explicit opt-in.
func TestRunner_MemUpdateZeroInterval_NoMemUpdate(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const entry uint32 = 0x08048000
	loop := []byte{0xEB, 0xFE}

	r, err := New(stub.Bytes)
	if err != nil {
		t.Fatalf("New: %v", err)
	}

	if err := r.WriteCode(entry, loop); err != nil {
		t.Fatalf("WriteCode: %v", err)
	}

	events := r.RunWithMode(entry, 0x701FFFF0, proto.ModeHost)

	deadline := time.After(300 * time.Millisecond)
	sawMemUpdate := false
loop_check:
	for {
		select {
		case ev, ok := <-events:
			if !ok {
				break loop_check
			}
			if _, isMemUpdate := ev.(proto.MemUpdate); isMemUpdate {
				sawMemUpdate = true
				break loop_check
			}
		case <-deadline:
			break loop_check
		}
	}

	// Teardown drainer + Close (see TestRunner_MemUpdateTicker for why).
	done := make(chan struct{})
	go func() {
		for range events {
		}
		close(done)
	}()
	_ = r.Close()
	<-done

	if sawMemUpdate {
		t.Error("MemUpdate emitted with no interval configured")
	}
}

// TestRunner_MemUpdateAndPauseCoexist makes sure the user's Pause()
// signal isn't accidentally consumed by the periodic snapshot
// consumer. Same fixture as the ticker test; after a few ticks we
// call Pause and expect a Paused (terminal) to land after the most
// recent MemUpdate, ending the session normally.
func TestRunner_MemUpdateAndPauseCoexist(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const entry uint32 = 0x08048000
	loop := []byte{0xEB, 0xFE}

	r, err := New(stub.Bytes)
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	// No defer Close — Pause winds the session down.

	if err := r.WriteCode(entry, loop); err != nil {
		t.Fatalf("WriteCode: %v", err)
	}

	events := r.RunWithModeAndMemUpdate(
		entry, 0x701FFFF0, proto.ModeHost, 50*time.Millisecond,
	)

	// Let a few ticks accumulate before calling Pause.
	time.Sleep(200 * time.Millisecond)
	if err := r.Pause(); err != nil {
		t.Fatalf("Pause: %v", err)
	}

	deadline := time.After(2 * time.Second)
	var memUpdates int
	var sawPaused bool
	for !sawPaused {
		select {
		case ev, ok := <-events:
			if !ok {
				t.Fatalf("events channel closed before Paused (memUpdates=%d)", memUpdates)
			}
			switch ev.(type) {
			case proto.MemUpdate:
				memUpdates++
			case proto.Paused:
				sawPaused = true
			}
		case <-deadline:
			t.Fatalf("Paused did not arrive after Pause (memUpdates=%d)", memUpdates)
		}
	}
	if memUpdates == 0 {
		t.Error("expected at least one MemUpdate before Pause (back-pressure or " +
			"snapshotPending race ate every one)")
	}
}
