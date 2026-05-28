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

// TestRunner_PauseEmitsPausedWithRegs demonstrates that Runner.Pause()
// cooperatively halts a running guest and produces a Paused Outbound
// carrying the canonical Context (Regs + sparse Regions). This is the
// engine-handoff trigger — a peer engine consumes the Paused and
// resumes via its own LoadContext.
//
// Hits the same tracer path the existing Close-interrupts-tight-loop
// test does (no-syscall guest, wait4 blocked on a tight loop) but
// uses SIGSTOP instead of SIGKILL, so the session ends with a Paused
// (Signal=SIGSTOP) instead of a kill-style Paused (Signal=SIGKILL).
func TestRunner_PauseEmitsPausedWithRegs(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const entry uint32 = 0x08048000
	// jmp short -2 → infinite loop. No syscalls, no signals — same
	// fixture the Close test uses, since we want the same "tracer
	// blocked in wait4 with no other activity" precondition.
	loop := []byte{0xEB, 0xFE}

	r, err := New(stub.Bytes)
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	// No defer Close() — Pause ends the session by itself; the
	// tracer's deferred cleanup runs from inside its goroutine.

	if err := r.WriteCode(entry, loop); err != nil {
		t.Fatalf("WriteCode: %v", err)
	}

	events := r.Run(entry, 0x701FFFF0)

	// Let the guest enter the loop. Tracer is blocked in wait4 with
	// no syscall traffic — the only way out is a signal.
	time.Sleep(50 * time.Millisecond)

	if err := r.Pause(); err != nil {
		t.Fatalf("Pause: %v", err)
	}

	deadline := time.After(2 * time.Second)
	var collected []proto.Outbound
loop_events:
	for {
		select {
		case ev, ok := <-events:
			if !ok {
				break loop_events
			}
			collected = append(collected, ev)
		case <-deadline:
			t.Fatalf("Pause did not surface a Paused within 2s; events so far: %#v", collected)
		}
	}

	if len(collected) == 0 {
		t.Fatal("expected at least one event after Pause")
	}
	paused, ok := collected[len(collected)-1].(proto.Paused)
	if !ok {
		t.Fatalf("final event: got %T, want proto.Paused", collected[len(collected)-1])
	}
	if paused.Signal != uint8(syscall.SIGSTOP) {
		t.Errorf("Paused.Signal: got %d, want %d (SIGSTOP from Runner.Pause)",
			paused.Signal, syscall.SIGSTOP)
	}
	if paused.Regs.Eip != entry {
		t.Errorf("Paused.Regs.Eip: got %#x, want %#x (the `jmp $` instruction)",
			paused.Regs.Eip, entry)
	}
	// Sparse regions: the guest stack region is freshly mmap'd and
	// largely zero, but flatten-start writes argc/argv/envp/auxv at
	// the top — that page is non-zero, so we expect at least one
	// region in the snapshot.
	if len(paused.Regions) == 0 {
		t.Error("Paused.Regions: expected at least one non-zero region (e.g. the stack-top scaffold), got 0")
	}
}
