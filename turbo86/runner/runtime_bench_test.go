//go:build linux

package runner

import (
	"debug/elf"
	"io"
	"os"
	"runtime"
	"sort"
	"strconv"
	"testing"
	"time"

	"github.com/sksat/x86.mov/turbo86/proto"
	"github.com/sksat/x86.mov/turbo86/stub"
)

// TestRuntimeBenchELF runs an arbitrary linked i386 ELF under turbo86 and
// reports a median native duration. It is env-gated because it is a benchmark
// harness, not a fixed correctness fixture:
//
//	TURBO86_RUNTIME_BENCH_ELF=/tmp/kernel.elf \
//	TURBO86_RUNTIME_BENCH_RUNS=25 \
//	  go test ./runner -run TestRuntimeBenchELF -count=1 -v
//
// ELF parsing, segment loading, and Runner construction happen before the
// timer. The duration starts immediately before Run and ends at the Exit
// event, so it includes ptrace start/exit overhead. Callers that need a
// kernel-only estimate should subtract a matched empty-loop ELF.
func TestRuntimeBenchELF(t *testing.T) {
	elfPath := os.Getenv("TURBO86_RUNTIME_BENCH_ELF")
	if elfPath == "" {
		t.Skip("set TURBO86_RUNTIME_BENCH_ELF to run the native benchmark")
	}
	runs := 25
	if value := os.Getenv("TURBO86_RUNTIME_BENCH_RUNS"); value != "" {
		parsed, err := strconv.Atoi(value)
		if err != nil || parsed < 1 {
			t.Fatalf("invalid TURBO86_RUNTIME_BENCH_RUNS=%q", value)
		}
		runs = parsed
	}

	f, err := elf.Open(elfPath)
	if err != nil {
		t.Fatalf("open ELF: %v", err)
	}
	defer f.Close()
	if f.Class != elf.ELFCLASS32 || f.Machine != elf.EM_386 {
		t.Fatalf("expected ELF32/i386, got class=%v machine=%v", f.Class, f.Machine)
	}

	type segment struct {
		addr uint32
		data []byte
	}
	var segments []segment
	for _, p := range f.Progs {
		if p.Type != elf.PT_LOAD || p.Filesz == 0 {
			continue
		}
		if p.Memsz > uint64(^uint32(0)) {
			t.Fatalf("segment @ 0x%x is too large: %d bytes", p.Vaddr, p.Memsz)
		}
		data := make([]byte, p.Memsz)
		if _, err := io.ReadFull(p.Open(), data[:p.Filesz]); err != nil {
			t.Fatalf("read segment @ 0x%x: %v", p.Vaddr, err)
		}
		segments = append(segments, segment{addr: uint32(p.Vaddr), data: data})
	}

	runtime.LockOSThread()
	defer runtime.UnlockOSThread()
	durations := make([]time.Duration, 0, runs)
	for run := 0; run < runs; run++ {
		r, err := New(stub.Bytes)
		if err != nil {
			t.Fatalf("run %d: New: %v", run, err)
		}
		for _, s := range segments {
			if err := r.WriteCode(s.addr, s.data); err != nil {
				r.Close()
				t.Fatalf("run %d: write segment @ 0x%x: %v", run, s.addr, err)
			}
		}

		start := time.Now()
		exited := false
		for event := range r.Run(uint32(f.Entry), 0x701ffff0) {
			switch value := event.(type) {
			case proto.Exit:
				durations = append(durations, time.Since(start))
				exited = true
			case proto.Fault:
				r.Close()
				t.Fatalf("run %d: guest faulted: %s", run, value.Reason)
			}
		}
		r.Close()
		if !exited {
			t.Fatalf("run %d: event stream ended without Exit", run)
		}
	}

	sort.Slice(durations, func(i, j int) bool { return durations[i] < durations[j] })
	median := durations[len(durations)/2]
	t.Logf("runtime_bench elf=%s runs=%d median_ns=%d", elfPath, runs, median.Nanoseconds())
}
