//go:build linux

package runner

import (
	"runtime"
	"syscall"
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

// TestRunner_MemUpdateTicker_InsnsAdvances pins that MemUpdate carries
// a retired-instruction count from perf_event_open and that the count
// actually grows between consecutive ticks for a guest in a tight
// `jmp $` loop (which retires the same insn over and over but the
// counter doesn't care — every retirement bumps it). Without this,
// the frontend's `total mov / mov per sec` cards would silently stay
// at the previously-substituted Outbound event count.
//
// Soft-skips when `perf_event_open` is denied (locked-down kernel /
// container) — the runtime fallback path emits Insns=0 by design, but
// asserting "first MemUpdate has Insns=0" would tell us nothing useful
// in that environment.
func TestRunner_MemUpdateTicker_InsnsAdvances(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	// Pre-flight: open a counter on our own PID to see if the kernel
	// even allows perf_event_open here. If not, skip — the runtime
	// path is already covered by the soft-degrade in `bootstrap`, and
	// asserting Insns=0 doesn't pin meaningful behaviour.
	if fd, err := openInsnCounter(0); err != nil {
		t.Skipf("perf_event_open unavailable in this environment: %v", err)
	} else {
		_ = syscall.Close(fd)
	}

	const entry uint32 = 0x08048000
	loop := []byte{0xEB, 0xFE} // jmp short -2

	r, err := New(stub.Bytes)
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	if r.perfFd == -1 {
		_ = r.Close()
		t.Skip("perf_event_open denied for child PID — same kernel policy")
	}
	if err := r.WriteCode(entry, loop); err != nil {
		_ = r.Close()
		t.Fatalf("WriteCode: %v", err)
	}

	events := r.RunWithModeAndMemUpdate(
		entry, 0x701FFFF0, proto.ModeHost, 50*time.Millisecond,
	)

	// Need two MemUpdates to compare counts.
	var first, second uint64
	deadline := time.After(2 * time.Second)
loop_events:
	for {
		select {
		case ev, ok := <-events:
			if !ok {
				t.Fatalf("events channel closed before 2 MemUpdates")
			}
			mu, isMemUpdate := ev.(proto.MemUpdate)
			if !isMemUpdate {
				continue
			}
			if first == 0 {
				first = mu.Insns
			} else {
				second = mu.Insns
				break loop_events
			}
		case <-deadline:
			break loop_events
		}
	}

	done := make(chan struct{})
	go func() {
		for range events {
		}
		close(done)
	}()
	_ = r.Close()
	<-done

	if first == 0 {
		t.Fatalf("first MemUpdate.Insns = 0; expected the perf counter to be non-zero by the first 50ms tick")
	}
	if second <= first {
		t.Errorf("MemUpdate.Insns did not advance between ticks: first=%d second=%d (jmp-self should keep retiring)", first, second)
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
	var got []proto.Outbound
	for {
		select {
		case ev, ok := <-events:
			if !ok {
				goto drained
			}
			got = append(got, ev)
			switch ev.(type) {
			case proto.MemUpdate:
				memUpdates++
			}
		case <-deadline:
			t.Fatalf("events channel did not close after Pause (memUpdates=%d)", memUpdates)
		}
	}

drained:
	if memUpdates == 0 {
		t.Error("expected at least one MemUpdate before Pause (back-pressure or " +
			"snapshotPending race ate every one)")
	}
	if len(got) == 0 {
		t.Fatal("no events received")
	}
	if _, ok := got[len(got)-1].(proto.Paused); !ok {
		t.Fatalf("last event = %#v, want Paused", got[len(got)-1])
	}
}
