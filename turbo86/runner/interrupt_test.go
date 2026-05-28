//go:build linux

package runner

import (
	"runtime"
	"testing"
	"time"

	"github.com/sksat/x86.mov/turbo86/proto"
	"github.com/sksat/x86.mov/turbo86/stub"
)

// TestRunner_CloseInterruptsTightLoop demonstrates that Runner.Close()
// can stop a guest that's spinning in a no-syscall tight loop. The
// kernel sees the SIGKILL Close sends, the tracer's wait4 returns
// Signaled, the runner emits a Paused, and the events channel closes.
//
// This is the primary "kill switch" for runaway guests — the upstream
// movfuscator master_loop dispatch trick is one concrete example of a
// guest that loops without making syscalls.
func TestRunner_CloseInterruptsTightLoop(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const entry uint32 = 0x08048000
	// jmp short -2 → infinite loop. Two bytes, no syscalls, no signals.
	//   EB FE                  jmp $
	loop := []byte{0xEB, 0xFE}

	r, err := New(stub.Bytes)
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	// Note: no defer r.Close() — the test calls Close explicitly to
	// verify it interrupts the in-flight loop.

	if err := r.WriteCode(entry, loop); err != nil {
		t.Fatalf("WriteCode: %v", err)
	}

	events := r.Run(entry, 0x701FFFF0)

	// Let the guest enter the loop. The tracer is blocked in wait4 by
	// now since the loop issues no syscalls.
	time.Sleep(50 * time.Millisecond)

	// Trigger the kill from a goroutine so we can keep draining events
	// concurrently.
	closeDone := make(chan struct{})
	go func() {
		_ = r.Close()
		close(closeDone)
	}()

	// Bound the test so an unexpected hang surfaces.
	deadline := time.After(2 * time.Second)
	var collected []proto.Outbound
	for {
		select {
		case ev, ok := <-events:
			if !ok {
				// Channel closed — runner cleanup complete.
				goto done
			}
			collected = append(collected, ev)
		case <-deadline:
			t.Fatalf("Close did not interrupt the tight loop within 2s; events so far: %#v", collected)
		}
	}
done:
	<-closeDone

	if len(collected) == 0 {
		t.Fatal("expected at least one event from Close-induced kill")
	}
	// SIGKILL from Close's kill() arrives as Signaled in wait4.
	paused, ok := collected[len(collected)-1].(proto.Paused)
	if !ok {
		t.Fatalf("final event: got %T, want proto.Paused", collected[len(collected)-1])
	}
	if paused.Signal != 9 { // SIGKILL
		t.Errorf("Paused.Signal: got %d, want 9 (SIGKILL from Runner.Close)", paused.Signal)
	}
}
