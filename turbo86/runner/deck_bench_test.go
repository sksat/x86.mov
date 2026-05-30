//go:build linux

package runner

import (
	"debug/elf"
	"io"
	"os"
	"runtime"
	"strconv"
	"testing"
	"time"

	"github.com/sksat/x86.mov/turbo86/proto"
	"github.com/sksat/x86.mov/turbo86/stub"
)

// TestDeckBench_NativeSpeed runs a SIMD86 bench deck (deck_bench.elf,
// which exits once it reaches the last slide) natively under turbo86,
// pre-queues (n-1) Right keys, and reports the wall-clock for
// "boot + initial blit + (n-1) slide transitions". This is the
// native-speed counterpart to the movie86 wasm number (~40 s/transition)
// — the whole point of the turbo86 handover for live presentation.
//
// Env-gated (the ELF is ~11 MiB, movfuscator-built, gitignored):
//
//	TURBO86_DECK_BENCH=/tmp/deck_bench.elf TURBO86_DECK_SLIDES=4 \
//	    go test ./runner -run TestDeckBench_NativeSpeed -v
func TestDeckBench_NativeSpeed(t *testing.T) {
	elfPath := os.Getenv("TURBO86_DECK_BENCH")
	if elfPath == "" {
		t.Skip("set TURBO86_DECK_BENCH=path/to/deck_bench.elf to run")
	}
	nSlides := 4
	if v := os.Getenv("TURBO86_DECK_SLIDES"); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil {
			t.Fatalf("bad TURBO86_DECK_SLIDES=%q", v)
		}
		nSlides = n
	}

	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	f, err := elf.Open(elfPath)
	if err != nil {
		t.Fatalf("open ELF: %v", err)
	}
	defer f.Close()

	r, err := New(stub.Bytes)
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	defer r.Close()

	for _, p := range f.Progs {
		if p.Type != elf.PT_LOAD || p.Filesz == 0 {
			continue
		}
		// The framebuffer segment (.fb13h @ ~0xA0000) sits outside the
		// stub's static guest region; the deck maps it itself at runtime
		// via mmap_request, exactly as it does in the live handover. Only
		// pre-load segments that land in the static code/data region.
		if p.Vaddr < 0x08048000 || p.Vaddr >= 0x09048000 {
			t.Logf("skip out-of-region segment @ 0x%x (guest mmaps it)", p.Vaddr)
			continue
		}
		buf := make([]byte, p.Filesz)
		if _, err := io.ReadFull(p.Open(), buf); err != nil {
			t.Fatalf("read segment @ 0x%x: %v", p.Vaddr, err)
		}
		if err := r.WriteCode(uint32(p.Vaddr), buf); err != nil {
			t.Fatalf("write segment @ 0x%x: %v", p.Vaddr, err)
		}
	}

	// Pre-queue (n-1) Right keys so the deck advances straight to the
	// last slide and exits.
	const keyRight uint8 = 0x81
	for i := 0; i < nSlides-1; i++ {
		r.PushInput(keyRight)
	}

	start := time.Now()
	events := r.Run(uint32(f.Entry), 0x701FFFF0)

	var exited bool
	timeout := time.After(120 * time.Second)
loop:
	for {
		select {
		case ev, ok := <-events:
			if !ok {
				break loop
			}
			t.Logf("event: %T", ev) // type only — Paused carries MBs of regions
			if _, isExit := ev.(proto.Exit); isExit {
				exited = true
				break loop
			}
			if fa, isFault := ev.(proto.Fault); isFault {
				t.Fatalf("guest faulted: %s", fa.Reason)
			}
		case <-timeout:
			t.Fatalf("deck did not exit within 120s (movfuscator master-loop wall?)")
		}
	}
	elapsed := time.Since(start)

	if !exited {
		t.Fatalf("events channel closed without Exit")
	}
	t.Logf("deck_bench: boot + initial blit + %d transitions in %v (%.1f ms/transition incl. boot)",
		nSlides-1, elapsed, float64(elapsed.Milliseconds())/float64(nSlides-1))
}
