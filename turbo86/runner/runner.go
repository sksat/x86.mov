//go:build linux

// Package runner drives the ptraced child stub: spawn, inject guest
// code, set registers, intercept syscalls via PTRACE_SYSCALL (entry +
// exit stop pairs), route them through the bridge, and collect the
// resulting protocol events.
//
// All ptrace operations target the OS thread that started the child, so
// callers MUST runtime.LockOSThread() before invoking RunOnce and not
// unlock until it returns. v1 exposes a one-shot API (RunOnce) per
// session; persistent streaming-server use comes in a later slice.
package runner

import (
	"bytes"
	"compress/gzip"
	"debug/elf"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"runtime"
	"sort"
	"sync"
	"syscall"
	"time"
	"unsafe"

	"github.com/sksat/x86.mov/turbo86/bridge"
	"github.com/sksat/x86.mov/turbo86/proto"
)

// PTRACE_GETREGSET / PTRACE_SETREGSET with NT_PRSTATUS — the only
// way to read/write the *architecture-appropriate* register set from a
// 64-bit tracer to a 32-bit tracee. The stdlib's PtraceGetRegs/SetRegs
// always uses the 64-bit user_regs_struct layout, which does not match
// what the kernel writes back for a 32-bit child (different field
// order + smaller size), leaving most fields as zero.
const (
	ptraceGetRegset = 0x4204
	ptraceSetRegset = 0x4205
	ntPrstatus      = 1
)

// orig_eax = -1 tells the kernel "this syscall number is invalid" — the
// syscall is rejected, eax is set to -ENOSYS at the exit stop, and no
// real kernel-side syscall runs. We overwrite eax with our synthetic
// return value at the exit stop to make the no-op transparent to the
// guest. Used by the emulate path under PTRACE_SYSCALL.
const suppressedSyscall = uint32(0xFFFFFFFF)

// In trap mode, the runner needs a guest-executable restorer trampoline
// so a normal-returning signal handler's `ret` lands somewhere the
// runner can intercept (rt_sigreturn). We write 7 bytes at a fixed
// address near the top of the guest's code region, then push that
// address onto the guest stack at signal dispatch so the handler's
// final `ret` pops into the trampoline.
//
//	B8 AD 00 00 00       mov  eax, 173       (__NR_rt_sigreturn)
//	CD 80                int  0x80
//
// 0x09040000 is near the top of the stub's 16 MiB RWX region (which
// starts at 0x08048000) and out of the way of typical mov-only code
// + data layouts.
const trapTrampolineAddr uint32 = 0x09040000

var trapTrampolineBytes = []byte{0xB8, 0xAD, 0x00, 0x00, 0x00, 0xCD, 0x80}

// __NR_memfd_create on amd64 Linux. Not exposed by syscall package.
const sysMemfdCreate = 319

// syscallTrap is the stop signal delivered with PTRACE_O_TRACESYSGOOD
// (SIGTRAP | 0x80) so the loop can distinguish syscall stops from real
// SIGTRAPs.
const syscallTrap = syscall.SIGTRAP | 0x80

// regs32 mirrors the kernel's i386 `struct pt_regs` (17 × 4 bytes = 68
// bytes), used as the payload of PTRACE_{GET,SET}REGSET / NT_PRSTATUS
// when tracing a 32-bit child.
type regs32 struct {
	Ebx, Ecx, Edx, Esi, Edi, Ebp, Eax uint32
	Ds, Es, Fs, Gs                    uint32
	OrigEax                           uint32
	Eip                               uint32
	Cs                                uint32
	Eflags                            uint32
	Esp                               uint32
	Ss                                uint32
}

// iovec matches the kernel ABI for `struct iovec` on amd64 (16 bytes).
type iovec struct {
	Base uintptr
	Len  uint64
}

func ptraceGetRegs32(pid int, r *regs32) error {
	iov := iovec{Base: uintptr(unsafe.Pointer(r)), Len: uint64(unsafe.Sizeof(*r))}
	_, _, errno := syscall.Syscall6(
		syscall.SYS_PTRACE, ptraceGetRegset, uintptr(pid),
		ntPrstatus, uintptr(unsafe.Pointer(&iov)), 0, 0,
	)
	if errno != 0 {
		return errno
	}
	return nil
}

func ptraceSetRegs32(pid int, r *regs32) error {
	iov := iovec{Base: uintptr(unsafe.Pointer(r)), Len: uint64(unsafe.Sizeof(*r))}
	_, _, errno := syscall.Syscall6(
		syscall.SYS_PTRACE, ptraceSetRegset, uintptr(pid),
		ntPrstatus, uintptr(unsafe.Pointer(&iov)), 0, 0,
	)
	if errno != 0 {
		return errno
	}
	return nil
}

// procMem reads / writes the guest address space via /proc/PID/mem and
// also satisfies bridge.GuestMemory.
type procMem struct {
	f *os.File
}

func (m *procMem) ReadAt(addr uint32, buf []byte) error {
	n, err := m.f.ReadAt(buf, int64(addr))
	if err != nil && !(err == io.EOF && n == len(buf)) {
		return err
	}
	if n != len(buf) {
		return fmt.Errorf("short read at 0x%x: got %d want %d", addr, n, len(buf))
	}
	return nil
}

func (m *procMem) WriteAt(addr uint32, data []byte) error {
	n, err := m.f.WriteAt(data, int64(addr))
	if err != nil {
		return err
	}
	if n != len(data) {
		return fmt.Errorf("short write at 0x%x: wrote %d want %d", addr, n, len(data))
	}
	return nil
}

// writeMem is an internal alias used by trap-mode helpers that want to
// stay readable next to the ReadAt calls; the runner's `mem` is a
// procMem so this just forwards.
func (r *Runner) writeMem(addr uint32, data []byte) error {
	return r.mem.WriteAt(addr, data)
}

// sniffHostSigaction peeks at the act struct of a host-mode rt_sigaction
// passthrough call so r.handlers stays in sync with what the kernel will
// be doing — purely advisory, used by the signal-stop branch to skip the
// memory snapshot when a handler is registered (the kernel will run it,
// the child won't die, the snapshot would be discarded). Failure to read
// guest memory is non-fatal: we just leave r.handlers as-is and pay the
// snapshot cost.
func (r *Runner) sniffHostSigaction(regs *regs32) {
	if regs.Ecx == 0 {
		return // pure-query call; disposition unchanged
	}
	signum := uint8(regs.Ebx)
	var buf [4]byte
	if err := r.mem.ReadAt(regs.Ecx, buf[:]); err != nil {
		return
	}
	handler := uint32(buf[0]) | uint32(buf[1])<<8 | uint32(buf[2])<<16 | uint32(buf[3])<<24
	if handler <= 1 {
		delete(r.handlers, signum)
	} else {
		r.handlers[signum] = handler
	}
}

// memfdCreate is a thin wrapper around the memfd_create(2) syscall.
// flags is the bitmask of MFD_* flags (MFD_CLOEXEC = 1).
func memfdCreate(name string, flags uint) (int, error) {
	namePtr, err := syscall.BytePtrFromString(name)
	if err != nil {
		return -1, err
	}
	r0, _, errno := syscall.Syscall(
		sysMemfdCreate,
		uintptr(unsafe.Pointer(namePtr)),
		uintptr(flags),
		0,
	)
	if errno != 0 {
		return -1, errno
	}
	return int(r0), nil
}

// protoRegs copies the GP + control fields from the kernel reg layout
// to the wire-protocol Regs (the canonical migration schema).
func protoRegs(r *regs32) proto.Regs {
	return proto.Regs{
		Eax:    r.Eax,
		Ebx:    r.Ebx,
		Ecx:    r.Ecx,
		Edx:    r.Edx,
		Esi:    r.Esi,
		Edi:    r.Edi,
		Ebp:    r.Ebp,
		Esp:    r.Esp,
		Eip:    r.Eip,
		Eflags: r.Eflags,
	}
}

// guestRegions are the address ranges the i386 stub maps for the guest.
// Kept in sync with stub/_stub.s — the only authority for these values
// is the stub assembly's mmap2 calls.
var guestRegions = []struct{ addr, size uint32 }{
	{0x08048000, 0x01000000}, // code/data: 16 MiB at the conventional ELF base
	{0x70000000, 0x00200000}, // stack:      2 MiB well clear of the stub's own stack
}

// GuestStackTop is the initial ESP for a fresh guest boot — the top of
// the stub's static stack region (0x70000000..0x70200000), 16 bytes
// below the end so the first push lands in-region. Used by the LoadElf
// handover, where the wire message carries no stack top (the deck boots
// like a fresh process). The Start path takes the stack top from the
// frontend instead. Matches the integration tests' testStackTop.
const GuestStackTop uint32 = 0x701FFFF0

// abiBase is the start of the mov-only ABI page. The page itself is
// deliberately left unmapped in the stub, so any guest write into it
// raises SIGSEGV; the runner intercepts that signal and interprets
// the offset within the page as a host call number (see classifyAbi
// below). Picked to sit between the stub's code region
// (`[0x08048000, 0x09048000)`) and stack region (`[0x70000000,
// 0x70200000)`) so it never collides with code, data, or stack.
const (
	abiBase     uint32 = 0x1FFE0000
	abiPageSize uint32 = 0x1000

	// Call numbers — page offsets. Keep these sparse to leave room for
	// related sub-calls (e.g. a "query video mode" pair next to
	// "set video mode") without renumbering downstream consumers.
	abiCallSetVideoMode uint16 = 0x010
	abiCallMmapRequest  uint16 = 0x020
	abiCallPollInput    uint16 = 0x040
	abiCallWrite        uint16 = 0x080
	abiCallExit         uint16 = 0x0FE

	// keyNone is the "no input pending" code returned by abiCallPollInput.
	// Mirrors movie86::abi_host::KEY_NONE — part of the cross-engine
	// contract. turbo86 has no input source wired yet, so every poll
	// reports keyNone; a future Inbound key-event message can feed real
	// codes through the same EAX return path.
	keyNone uint8 = 0x00
)

// i386 mmap2 args / packing for the mov-only ABI mmap_request call.
//
// `eax[31:12]` = page-aligned target addr (top 20 bits), `eax[11:0]` =
// pages - 1 (so max 4096 pages = 16 MiB per single request). The
// resulting region is mapped PROT_RWX, MAP_FIXED|MAP_ANONYMOUS|
// MAP_PRIVATE — same shape the stub uses for its static regions, so
// dynamic and static regions are indistinguishable on the wire.
const (
	sysMmap2 uint32 = 192 // __NR_mmap2 on i386 — not exposed via stdlib

	mmapProtRWX    uint32 = 0x7  // PROT_READ | PROT_WRITE | PROT_EXEC
	mmapFlagsFixed uint32 = 0x32 // MAP_FIXED | MAP_ANONYMOUS | MAP_PRIVATE
	mmapAddrMask   uint32 = 0xFFFFF000
	mmapSizeMask   uint32 = 0xFFF
	mmapMaxRegions        = 32 // soft cap on dynamic regions per session
)

// pageSize is the smallest snapshot granule. Anonymous mmap mappings
// are demand-zero — pages that the guest never touched read as zeros
// via /proc/PID/mem and are skipped here.
const pageSize = 4096

// snapshotMemory reads each known guest region and returns the non-zero
// 4 KiB pages as MemRegion entries. Adjacent non-zero pages are merged
// into a single MemRegion run. For a freshly-faulted guest this drops
// the encoded payload from ~18 MiB to a few KiB.
//
// The child MUST be stopped before this is called (otherwise pages can
// race under your read); the runner only invokes it at ptrace stops.
func (r *Runner) snapshotMemory() ([]proto.MemRegion, error) {
	var out []proto.MemRegion

	// Walk static guestRegions plus any runtime-mmap'd regions
	// (mov-only ABI mmap_request, call 0x020). Both kinds are
	// indistinguishable from `proto.MemRegion` consumers' point of
	// view — the wire format only carries (addr, bytes).
	walk := func(addr, size uint32) error {
		buf := make([]byte, size)
		if err := r.mem.ReadAt(addr, buf); err != nil {
			return fmt.Errorf("snapshot region 0x%x..0x%x: %w", addr, addr+size, err)
		}
		var i uint32
		for i < size {
			for i < size && allZero(buf[i:i+pageSize]) {
				i += pageSize
			}
			if i >= size {
				break
			}
			runStart := i
			for i < size && !allZero(buf[i:i+pageSize]) {
				i += pageSize
			}
			out = append(out, proto.MemRegion{
				Addr:  addr + runStart,
				Bytes: append([]byte(nil), buf[runStart:i]...),
			})
		}
		return nil
	}
	// When the session declared watch regions (the large-deck LoadElf
	// path), the periodic snapshot scans ONLY those ranges — not the full
	// static + extra map. A SIMD86 deck bakes ~160 MiB of immutable slide
	// pixels into .rodata; re-streaming all of it every interval would
	// swamp the wire, so the frontend watches just the framebuffer range
	// that actually changes. Empty watchRegions falls back to the original
	// "walk every mapped region" behaviour below.
	//
	// The frontend watches EVERY known framebuffer mode address, but a
	// deck only mmaps the FB(s) it actually uses — so most watch ranges
	// point at unmapped guest memory. A bare walk of an unmapped range
	// short-reads /proc/PID/mem and would fault the whole boost session.
	// Intersect each watch range with the regions that are actually mapped
	// (the static guestRegions + runtime mmap_request grants in
	// extraRegions) and walk only the overlap; unmapped watch ranges are
	// silently skipped.
	if len(r.watchRegions) > 0 {
		mapped := append([]struct{ addr, size uint32 }(nil), guestRegions...)
		r.extraRegionsMu.RLock()
		mapped = append(mapped, r.extraRegions...)
		r.extraRegionsMu.RUnlock()
		for _, w := range r.watchRegions {
			wStart := w.Addr & mmapAddrMask
			wEnd := (w.Addr + w.Size + (pageSize - 1)) & mmapAddrMask
			if wEnd <= wStart {
				continue // zero-size or wrapping watch range — skip
			}
			for _, m := range mapped {
				start, end := wStart, wEnd
				if m.addr > start {
					start = m.addr
				}
				if m.addr+m.size < end {
					end = m.addr + m.size
				}
				if start >= end {
					continue // no overlap with this mapped region
				}
				if err := walk(start, end-start); err != nil {
					return nil, err
				}
			}
		}
		return out, nil
	}

	for _, gr := range guestRegions {
		if err := walk(gr.addr, gr.size); err != nil {
			return nil, err
		}
	}
	// Copy extraRegions under the lock so the tracer goroutine can
	// still append (mmap_request handler) without racing the walk.
	// The async MemUpdate ticker is the other reader; without the
	// snapshot under lock a guest that calls mmap_request mid-run
	// would trigger a Go data race on the slice header.
	r.extraRegionsMu.RLock()
	extras := make([]struct{ addr, size uint32 }, len(r.extraRegions))
	copy(extras, r.extraRegions)
	r.extraRegionsMu.RUnlock()
	for _, gr := range extras {
		if err := walk(gr.addr, gr.size); err != nil {
			return nil, err
		}
	}
	return out, nil
}

func allZero(b []byte) bool {
	for _, x := range b {
		if x != 0 {
			return false
		}
	}
	return true
}

// RunOnce executes a single guest session starting fresh.
//
// Convenience wrapper around the long-lived Runner for the common case:
// no streaming, all code known up front. New code arriving while the
// guest is executing — the streaming use case — needs the Runner API
// directly (see New/WriteCode/Run).
//
// `code` maps guest virtual addresses → bytes to write into the guest's
// RWX region before execution begins. `entry` is the initial EIP;
// `stackTop` is the initial ESP.
//
// The caller's goroutine must be LockOSThread'd; all ptrace requests
// target the OS thread that became the tracer at exec.Cmd.Start().
func RunOnce(
	stubBytes []byte,
	code map[uint32][]byte,
	entry uint32,
	stackTop uint32,
) ([]proto.Outbound, error) {
	r, err := New(stubBytes)
	if err != nil {
		return nil, err
	}
	defer r.Close()
	for addr, data := range code {
		if err := r.WriteCode(addr, data); err != nil {
			return nil, err
		}
	}
	return collectEvents(r.Run(entry, stackTop))
}

// RunWithContext resumes a guest session from a Context handed off by
// another engine (e.g., movie86). Convenience wrapper for the no-
// streaming case; see RunWithContextStreaming on Runner for the
// post-Resume Code-streaming variant.
//
// Same LockOSThread requirement as RunOnce.
func RunWithContext(stubBytes []byte, ctx proto.Context) ([]proto.Outbound, error) {
	r, err := New(stubBytes)
	if err != nil {
		return nil, err
	}
	defer r.Close()
	return collectEvents(r.RunWithContext(ctx))
}

// Runner is a long-lived guest session, driven by an internal "tracer"
// goroutine pinned to one OS thread. The lifecycle is:
//
//  1. New(stubBytes) spawns the stub, attaches via ptrace, drives it to
//     its self-SIGSTOP, opens /proc/PID/mem. After this the child is
//     stopped, regs / memory writable, ready for setup.
//  2. WriteCode(offset, bytes) writes guest memory directly via the
//     /proc fd — does NOT involve ptrace, so it's safe to call from
//     any goroutine, before OR after Run. Streaming use case: the
//     frontend keeps sending Code messages after Run kicks off; each
//     one just writes into the (still-mapped) RWX region.
//  3. Run(entry, stackTop) / RunWithContext(ctx) sets EIP/ESP and
//     enters the syscall-bridge loop. Returns a channel that streams
//     Outbound events; the channel is closed when the session ends.
//     Calling Run/RunWithContext is one-shot per Runner.
//  4. Close() kills the child and reaps it.
//
// Concurrency: WriteCode is goroutine-safe. Run/RunWithContext and
// Close are intended to be called from the orchestrating goroutine
// (typically the WS handler); calling Run twice or after Close is
// a programmer error.
type Runner struct {
	cmd *exec.Cmd
	pid int
	mem *procMem

	// perfFd is the perf_event_open file descriptor counting retired
	// instructions on the child. -1 when the kernel rejected the open
	// (typical on locked-down containers with
	// `kernel.perf_event_paranoid > 2`). The MemUpdate ticker treats
	// -1 as "counter unavailable" and emits Insns=0 so the field is
	// always present on the wire but optionally meaningful.
	perfFd int

	startCh   chan startMsg
	eventsCh  chan proto.Outbound
	closeCh   chan struct{}
	done      chan struct{}
	closeOnce sync.Once

	// inputCh is the runner's input queue feeding the CALL_POLL_INPUT
	// ABI. The orchestrating goroutine (WS handler) PushInputs key codes
	// onto it; the tracer goroutine drains one per poll, non-blocking
	// both ways. Buffered so a burst of keystrokes between polls isn't
	// lost; a full buffer drops the oldest-unread excess (a held arrow
	// key spamming faster than the guest polls is the only way to hit
	// it, and dropping there is the right behaviour — see PushInput).
	inputCh chan uint8

	// tickerStop is closed by the tracer goroutine's defer to signal
	// the MemUpdate ticker (if running) to wind down, and tickerWg
	// is the join handle the defer waits on **before** closing
	// eventsCh. Without the wait the ticker's `select { send,
	// tickerStop }` could pick the send case after we've closed
	// eventsCh and panic with "send on closed channel" — a real
	// hazard when a terminal event races a pending MemUpdate.
	// Created in `New`.
	tickerStop chan struct{}
	tickerWg   sync.WaitGroup

	// memUpdateEnabled mirrors "the caller asked for periodic MemUpdate
	// events" (interval > 0). When set, the terminal path flushes one
	// final MemUpdate at session end so a progressive-display consumer
	// (the explorer canvas) sees the guest's last frame — the periodic
	// ticker can otherwise be up to one interval stale, and a trap-mode
	// guest paints via the mov-only video ABI right up to CALL_EXIT.
	// Sessions that didn't opt in (interval 0, e.g. RunOnce) emit no
	// trailing MemUpdate, so their exact event-sequence goldens hold.
	memUpdateEnabled bool

	// extraRegionsMu guards extraRegions against concurrent access
	// between the tracer goroutine (which appends in the mmap_request
	// ABI path) and the MemUpdate ticker goroutine (which iterates the
	// slice via snapshotMemory). Without it a guest that grows its
	// address space mid-session triggers a Go data race on the slice
	// header.
	extraRegionsMu sync.RWMutex

	// Mode-dependent state, populated when the syscall loop starts.
	mode       proto.Mode       // host (default) or trap
	handlers   map[uint8]uint32 // signum → handler addr (trap mode only)
	signalRegs []regs32         // saved regs stack for rt_sigreturn (trap mode only)

	// extraRegions is the runtime-mmap'd regions added on top of the
	// static `guestRegions` set, one per successful mov-only ABI
	// `mmap_request` (call 0x020). snapshotMemory walks these too so
	// guests that grow their address space mid-session don't have to
	// pre-declare every region; the Pause / Fault snapshot stays
	// accurate. Only touched from the tracer goroutine.
	extraRegions []struct{ addr, size uint32 }

	// watchRegions, when non-empty, restricts the periodic-MemUpdate
	// memory snapshot to just these guest ranges instead of walking
	// every mapped region. Set by LoadElf for the large-deck handover:
	// a SIMD86 deck bakes ~160 MiB of slide pixels into read-only
	// .rodata that never changes at runtime, so the default "scan all
	// mapped pages" walk would re-stream the whole deck every interval.
	// Empty preserves the original full-scan behaviour. Page-aligned in
	// snapshotMemory. Set before the tracer goroutine reads it (in
	// LoadElf, before Run delivers the start message).
	watchRegions []proto.WatchRegion

	// loadElfPlan is the parsed PT_LOAD plan staged by LoadElf, applied
	// by the tracer goroutine at start (inside tracerLoop, where the
	// trampoline exists and injectSyscall's ptrace preconditions hold).
	// nil for non-LoadElf sessions. Set before Run delivers the start
	// message, read once by the tracer goroutine.
	loadElfPlan *elfPlan

	// memUpdateIntervalMs is the LoadElf-requested periodic MemUpdate
	// cadence in milliseconds (0 = disabled). LoadElf records it here so
	// the tracer goroutine can start the ticker even when the caller used
	// the plain Run entry point (which carries no interval). 0 for
	// non-LoadElf sessions, which pass the interval via startMsg instead.
	memUpdateIntervalMs uint32

	// (No periodic-snapshot flags — the MemUpdate ticker reads
	// /proc/PID/mem from a separate goroutine without stopping the
	// tracee, so it doesn't interact with the tracer's signal-stop
	// machinery. Pause()'s SIGSTOP path is unchanged.)
}

type startMsg struct {
	withCtx           bool
	entry             uint32
	stackTop          uint32
	ctx               proto.Context
	mode              proto.Mode
	memUpdateInterval time.Duration
}

// New spawns the stub and drives it to its self-SIGSTOP. The internal
// tracer goroutine is OS-thread-locked for the lifetime of the Runner.
// Returns once the child is paused and /proc/PID/mem is open; callers
// may then WriteCode at will and eventually call Run / RunWithContext.
func New(stubBytes []byte) (*Runner, error) {
	r := &Runner{
		startCh: make(chan startMsg, 1),
		// Unbuffered: each event the tracer emits blocks until the
		// consumer reads, so the tracer can't outrun the consumer and
		// tear down resources (mem fd, child) before mid-session
		// streaming writes have a chance to land.
		eventsCh:   make(chan proto.Outbound),
		closeCh:    make(chan struct{}),
		done:       make(chan struct{}),
		tickerStop: make(chan struct{}),
		perfFd:     -1,
		// Buffered: keystrokes arrive on the WS goroutine and are drained
		// on the tracer goroutine at poll time. 256 is plenty for human
		// input between polls; overflow drops excess (PushInput).
		inputCh: make(chan uint8, 256),
	}

	bootErr := make(chan error, 1)
	go r.tracerLoop(stubBytes, bootErr)
	if err := <-bootErr; err != nil {
		<-r.done // ensure tracer goroutine cleanup ran
		return nil, err
	}
	return r, nil
}

// WriteCode writes `data` at guest virtual address `offset`. Safe from
// any goroutine. After Run begins, writes are *not* synchronized with
// guest execution — callers must arrange that they only write to
// pages the guest isn't currently executing / reading.
func (r *Runner) WriteCode(offset uint32, data []byte) error {
	return r.mem.WriteAt(offset, data)
}

// Run sets EIP=entry / ESP=stackTop and enters the syscall-bridge loop
// in the default host mode (kernel handles signal dispatch). Returns a
// channel that streams Outbound events in order; the channel closes
// when the session ends (Exit / Paused / Fault).
//
// One-shot per Runner: do not call Run / RunWithContext / *Mode more
// than once.
func (r *Runner) Run(entry, stackTop uint32) <-chan proto.Outbound {
	return r.RunWithMode(entry, stackTop, proto.ModeHost)
}

// RunWithMode is Run with explicit mode selection (host / trap).
func (r *Runner) RunWithMode(entry, stackTop uint32, mode proto.Mode) <-chan proto.Outbound {
	r.startCh <- startMsg{entry: entry, stackTop: stackTop, mode: mode}
	return r.eventsCh
}

// RunWithContext writes ctx.Regions into guest memory, sets the full
// reg file from ctx.Regs, then enters the syscall-bridge loop in the
// default host mode. Same channel semantics as Run.
func (r *Runner) RunWithContext(ctx proto.Context) <-chan proto.Outbound {
	return r.RunWithContextAndMode(ctx, proto.ModeHost)
}

// RunWithContextAndMode is RunWithContext with explicit mode selection.
func (r *Runner) RunWithContextAndMode(ctx proto.Context, mode proto.Mode) <-chan proto.Outbound {
	r.startCh <- startMsg{withCtx: true, ctx: ctx, mode: mode}
	return r.eventsCh
}

// RunWithModeAndMemUpdate is RunWithMode plus periodic MemUpdate
// Outbound events. `memUpdateInterval` controls the cadence: zero
// disables (identical to RunWithMode), values > 0 enable a background
// goroutine that SIGSTOPs the child every `memUpdateInterval`, the
// tracer catches the resulting stop, emits a `proto.MemUpdate` with
// the sparse memory snapshot, and resumes the guest. Typical use:
// `100 * time.Millisecond` for a browser frontend driving a canvas
// that wants to show partial decoder output mid-run.
func (r *Runner) RunWithModeAndMemUpdate(
	entry, stackTop uint32, mode proto.Mode, memUpdateInterval time.Duration,
) <-chan proto.Outbound {
	r.startCh <- startMsg{
		entry: entry, stackTop: stackTop, mode: mode,
		memUpdateInterval: memUpdateInterval,
	}
	return r.eventsCh
}

// RunWithContextModeAndMemUpdate is RunWithContextAndMode plus periodic
// MemUpdate (see RunWithModeAndMemUpdate for the cadence semantics).
func (r *Runner) RunWithContextModeAndMemUpdate(
	ctx proto.Context, mode proto.Mode, memUpdateInterval time.Duration,
) <-chan proto.Outbound {
	r.startCh <- startMsg{
		withCtx: true, ctx: ctx, mode: mode,
		memUpdateInterval: memUpdateInterval,
	}
	return r.eventsCh
}

// guestArenaBase / guestArenaSize name the stub's static 16 MiB
// code/data arena — the first entry of guestRegions. LoadElf segments
// that fall entirely inside [guestArenaBase, guestArenaBase+guestArenaSize)
// are already mapped by the stub and just need a write; anything outside
// needs a dynamic mmap first (same path LoadContext / mmap_request use).
const (
	guestArenaBase uint32 = 0x08048000
	guestArenaSize uint32 = 0x01000000
)

// elfWriteChunk caps a single writeMem call when loading a PT_LOAD
// segment. process_vm_writev (under /proc/PID/mem) can short-write on a
// huge single call, so we split large segments (the SIMD86 deck's
// ~160 MiB .rodata) into <= 8 MiB pieces.
const elfWriteChunk = 8 << 20

// elfSegment is one page-aligned PT_LOAD plan entry: the bytes to write
// at vaddr (filesz), the mapped span [mapStart, mapEnd) the loader must
// ensure is present, and whether that span is fully inside the static
// arena (no mmap needed) or must be dynamically mmap'd first.
type elfSegment struct {
	vaddr    uint32
	data     []byte // first p_filesz bytes; BSS tail is anon-zero
	mapStart uint32 // page-aligned segment start
	mapEnd   uint32 // page-aligned segment end (exclusive)
	inArena  bool   // mapStart..mapEnd entirely inside the static arena
}

// elfPlan is the parsed, validated PT_LOAD plan LoadElf stages for the
// tracer goroutine to apply at start. entry is the ELF e_entry (becomes
// guest EIP). The ptrace work (mmap + write + SetRegs) happens inside
// tracerLoop, where the trampoline is materialised and injectSyscall's
// "must be at a ptrace stop on the tracer thread" precondition holds.
type elfPlan struct {
	entry    uint32
	segments []elfSegment
}

// LoadElf parses a complete mov-only ELF32 (i386) image and stages its
// PT_LOAD segments for execution from the ELF entry point — the
// "large-deck" handover that ships the compact ELF instead of migrating
// ~160 MiB of live guest memory. The image is reconstructed natively:
// segments inside the stub's static arena are written directly, segments
// outside it are mmap'd into the guest (anon, RWX, MAP_FIXED) first.
//
// LoadElf does the parse / validation synchronously and records the plan
// + session knobs (mode, watch regions, MemUpdate cadence) on the
// Runner; the actual ptrace work (mmap injection, segment writes, EIP/ESP
// setup) runs in the tracer goroutine when Run delivers the start
// message — that's the only context where injectSyscall's preconditions
// (trampoline present, child at a tracer-driven ptrace stop) hold. Like
// LoadContext, LoadElf does NOT call Run; the caller (server) calls Run
// afterwards to kick the syscall loop.
//
// Intended for host mode: a fresh deck boot uses host mode. In trap mode
// LoadElf rejects an image whose mapped segments would collide with the
// trap restorer trampoline (0x09040000), rather than silently
// overwriting it.
//
// The image may arrive gzip-compressed (detected by the 1F 8B magic):
// the SIMD86 deck bakes ~160 MiB of raw RGBA into .rodata, which the
// browser gzips with CompressionStream before sending so a few-MiB
// payload crosses the WebSocket instead of a ~213 MiB base64 string.
// A gzip image is inflated here before the ELF parse; a raw ELF (7F 'E'
// 'L' 'F') is parsed directly, so existing raw-ELF callers are unaffected.
func (r *Runner) LoadElf(img []byte, mode proto.Mode, memUpdateMs uint32, watch []proto.WatchRegion) error {
	// gzip magic (1F 8B) distinguishes a compressed image from a raw ELF
	// (7F 45 4C 46). Inflate before parsing; raw ELFs fall straight through.
	if len(img) >= 2 && img[0] == 0x1f && img[1] == 0x8b {
		gr, err := gzip.NewReader(bytes.NewReader(img))
		if err != nil {
			return fmt.Errorf("LoadElf: open gzip reader: %w", err)
		}
		defer gr.Close()
		// Cap the inflated size so a malformed/hostile gzip can't OOM the
		// process. turbo86 is a localhost dev tool, but the bound is cheap
		// insurance. 512 MiB matches the server's WS read limit and leaves
		// ample room over the ~160 MiB deck. Read one extra byte to detect
		// (rather than silently truncate) an over-cap image.
		const maxElfImageBytes = 512 << 20
		decompressed, err := io.ReadAll(io.LimitReader(gr, maxElfImageBytes+1))
		if err != nil {
			return fmt.Errorf("LoadElf: gunzip image: %w", err)
		}
		if len(decompressed) > maxElfImageBytes {
			return fmt.Errorf("LoadElf: decompressed image exceeds %d bytes", maxElfImageBytes)
		}
		img = decompressed
	}
	f, err := elf.NewFile(bytes.NewReader(img))
	if err != nil {
		return fmt.Errorf("LoadElf: parse ELF: %w", err)
	}
	if f.Class != elf.ELFCLASS32 {
		return fmt.Errorf("LoadElf: not ELFCLASS32 (got %s)", f.Class)
	}
	if f.Machine != elf.EM_386 {
		return fmt.Errorf("LoadElf: not EM_386 (got %s)", f.Machine)
	}
	if f.Entry > 0xFFFFFFFF {
		return fmt.Errorf("LoadElf: entry 0x%x out of 32-bit range", f.Entry)
	}

	plan := &elfPlan{entry: uint32(f.Entry)}
	for _, p := range f.Progs {
		if p.Type != elf.PT_LOAD {
			continue
		}
		vaddr := uint32(p.Vaddr)
		memsz := uint32(p.Memsz)
		mapStart := vaddr & mmapAddrMask
		mapEnd := (vaddr + memsz + (pageSize - 1)) & mmapAddrMask
		if mapEnd <= mapStart {
			return fmt.Errorf("LoadElf: segment at 0x%x size 0x%x wraps", vaddr, memsz)
		}
		// A valid ELF has filesz <= memsz; the reverse would have us write
		// more bytes (filesz) than the region is mapped for (sized from
		// memsz), overrunning the mapping. Reject malformed images.
		if uint32(p.Filesz) > memsz {
			return fmt.Errorf("LoadElf: segment at 0x%x filesz 0x%x exceeds memsz 0x%x",
				vaddr, p.Filesz, memsz)
		}
		// Read the first p_filesz bytes via the program header (handles
		// p_offset / compression / the file image). The Memsz-Filesz BSS
		// tail needs no write: in-arena pages start zero, and an anon
		// mmap is demand-zero.
		data := make([]byte, p.Filesz)
		if p.Filesz > 0 {
			if _, err := io.ReadFull(p.Open(), data); err != nil {
				return fmt.Errorf("LoadElf: read segment at 0x%x: %w", vaddr, err)
			}
		}
		inArena := mapStart >= guestArenaBase &&
			mapEnd <= guestArenaBase+guestArenaSize
		plan.segments = append(plan.segments, elfSegment{
			vaddr:    vaddr,
			data:     data,
			mapStart: mapStart,
			mapEnd:   mapEnd,
			inArena:  inArena,
		})
	}
	if len(plan.segments) == 0 {
		return errors.New("LoadElf: no PT_LOAD segments")
	}

	// Trap mode shares the guest address space with the rt_sigreturn
	// restorer trampoline at trapTrampolineAddr; a deck whose segments
	// reach that page would clobber it. LoadElf is intended for the
	// fresh-deck host-mode boot, so reject the collision loudly rather
	// than corrupt the trampoline.
	if mode == proto.ModeTrap {
		const trampPage = trapTrampolineAddr & mmapAddrMask
		for _, s := range plan.segments {
			if trampPage >= s.mapStart && trampPage < s.mapEnd {
				return fmt.Errorf(
					"LoadElf: trap-mode trampoline 0x%x collides with segment 0x%x..0x%x (use host mode)",
					trapTrampolineAddr, s.mapStart, s.mapEnd)
			}
		}
	}

	r.mode = mode
	r.memUpdateIntervalMs = memUpdateMs
	r.watchRegions = watch
	r.loadElfPlan = plan
	return nil
}

// mapSegmentGaps backs [start,end) (page-aligned guest addresses) with
// guest memory, mmapping ONLY the pages not already mapped — by the
// stub's static guestRegions or a previously-mapped segment recorded in
// extraRegions. This matters when PT_LOAD segments share a page, or a
// segment partially overlaps the static arena (the deck's .rodata starts
// inside the arena and runs past it): a blanket MAP_FIXED mmap of the
// whole range would re-map — and zero — pages an earlier segment already
// wrote, and would waste the mmapMaxRegions budget on redundant mappings.
// Gaps are mmap'd via mmapRegionForLoadContext (the same injectSyscall
// path), so they land in extraRegions and the snapshot walk picks them
// up. Caller must be on the tracer thread with the child stopped.
func (r *Runner) mapSegmentGaps(start, end uint32, regs *regs32) error {
	type iv struct{ a, b uint32 }
	var mapped []iv
	for _, gr := range guestRegions {
		mapped = append(mapped, iv{gr.addr, gr.addr + gr.size})
	}
	r.extraRegionsMu.RLock()
	for _, er := range r.extraRegions {
		mapped = append(mapped, iv{er.addr, er.addr + er.size})
	}
	r.extraRegionsMu.RUnlock()
	sort.Slice(mapped, func(i, j int) bool { return mapped[i].a < mapped[j].a })

	cur := start
	for _, m := range mapped {
		if cur >= end {
			break
		}
		if m.b <= cur || m.a >= end {
			continue // no overlap with the remaining [cur,end)
		}
		if m.a > cur {
			gapEnd := m.a
			if gapEnd > end {
				gapEnd = end
			}
			if err := r.mmapRegionForLoadContext(cur, gapEnd-cur, regs); err != nil {
				return err
			}
		}
		if m.b > cur {
			cur = m.b
		}
	}
	if cur < end {
		if err := r.mmapRegionForLoadContext(cur, end-cur, regs); err != nil {
			return err
		}
	}
	return nil
}

// applyElfPlan maps and writes the staged PT_LOAD segments into the
// stopped guest. Called once from tracerLoop after the trampoline is
// written and before the syscall loop starts, so injectSyscall (used by
// mmapRegionForLoadContext for out-of-arena segments) has a valid
// trampoline + ptrace stop to work with. regs is the live register set;
// mmap injection mutates and restores it.
func (r *Runner) applyElfPlan(plan *elfPlan, regs *regs32) error {
	// Two phases, and the order is load-bearing. Phase 1 maps every
	// out-of-arena segment via injectSyscall, which hijacks the guest EIP
	// onto the trampoline's `CD 80` at trapTrampolineAddr (0x09040000).
	// Phase 2 then writes all the segment bytes. They MUST NOT interleave:
	// the SIMD86 deck's ~160 MiB read-only .rodata starts inside the static
	// arena and runs past 0x09040000, so writing it clobbers the
	// trampoline. If a later segment (e.g. .bss above the arena) still
	// needed an mmap after that write, its injectSyscall would jump onto
	// the overwritten bytes and the guest would take SIGILL. Doing every
	// mmap first — while the trampoline is still intact — removes that
	// ordering hazard regardless of PT_LOAD order in the file.
	for _, s := range plan.segments {
		if !s.inArena {
			if err := r.mapSegmentGaps(s.mapStart, s.mapEnd, regs); err != nil {
				return fmt.Errorf("mmap ELF segment 0x%x..0x%x: %w", s.mapStart, s.mapEnd, err)
			}
		}
	}
	for _, s := range plan.segments {
		// Write file bytes in <= elfWriteChunk pieces: a single huge
		// process_vm_writev can short-write, so chunk the SIMD86 deck's
		// multi-MiB segments.
		for off := 0; off < len(s.data); off += elfWriteChunk {
			end := off + elfWriteChunk
			if end > len(s.data) {
				end = len(s.data)
			}
			if err := r.writeMem(s.vaddr+uint32(off), s.data[off:end]); err != nil {
				return fmt.Errorf("write ELF segment at 0x%x: %w", s.vaddr+uint32(off), err)
			}
		}
	}

	// Re-install the trampoline if any segment's written bytes covered
	// it. tracerLoop materialises trapTrampolineBytes at trapTrampolineAddr
	// (0x09040000) BEFORE applyElfPlan runs, but that address sits inside
	// the static arena [0x08048000, 0x09048000) — a real SIMD86 deck's
	// ~160 MiB read-only .rodata can easily span it, so the segment write
	// above would clobber the `CD 80` injectSyscall depends on. Without
	// this, the deck's own runtime mmap_request (and any other injected
	// syscall) would jump onto the segment's bytes and fault. We rewrite
	// the few trampoline bytes last so they win. Host mode only matters
	// here: LoadElf rejects an overlapping segment in trap mode up front.
	const trampPage = trapTrampolineAddr & mmapAddrMask
	for _, s := range plan.segments {
		if trampPage >= s.mapStart && trampPage < s.mapEnd {
			if err := r.writeMem(trapTrampolineAddr, trapTrampolineBytes); err != nil {
				return fmt.Errorf("re-install trampoline after ELF load: %w", err)
			}
			break
		}
	}
	return nil
}

// Close signals shutdown and waits for the tracer goroutine to finish.
// Idempotent. Safe to call from any goroutine.
//
// All cleanup (kill child, reap, close mem fd, close events channel)
// happens inside the tracer goroutine's defer; Close just signals it
// and blocks on r.done.
func (r *Runner) Close() error {
	r.closeOnce.Do(func() {
		close(r.closeCh)
		// Kicking the child wakes the tracer's wait4 so it can clean up.
		if r.cmd != nil && r.cmd.Process != nil {
			_ = r.cmd.Process.Kill()
		}
	})
	<-r.done
	return nil
}

// Pause asks the runner to cooperatively halt the current session and
// emit a Paused Outbound carrying the canonical Context (Regs +
// sparse Regions). The session ends; the events channel closes
// normally after the Paused is delivered. Safe from any goroutine —
// like Close, this just signals the kernel and lets the tracer
// goroutine handle the resulting ptrace-stop.
//
// Mechanism: sends SIGSTOP to the child. SIGSTOP is non-forwardable
// (job-control), so the existing tracer path that handles
// non-forwardable signal stops fires — it captures regs + sparse
// memory and emits a Paused. The same path runs whether the SIGSTOP
// came from a Pause Inbound or any other source.
//
// Boundary semantics: the stop lands at whatever ptrace-stop
// granularity the child happens to be at — usually an instruction
// boundary, but possibly mid-syscall-trap. Peer engines already
// tolerate the same caveat for signal-driven Paused events.
//
// Race tolerance: if the child has already exited (because the guest
// returned naturally, or a fault took the session down) before
// SIGSTOP could be delivered, the kernel returns
// `os.ErrProcessDone` — that's benign for an engine-handoff trigger
// (the caller just sees the natural end-of-session event instead of
// a Paused), so we swallow it.
func (r *Runner) Pause() error {
	if r.cmd == nil || r.cmd.Process == nil {
		return nil
	}
	if err := r.cmd.Process.Signal(syscall.SIGSTOP); err != nil &&
		!errors.Is(err, os.ErrProcessDone) {
		return err
	}
	return nil
}

// PushInput enqueues one generic input key code for the guest to read
// via the CALL_POLL_INPUT ABI. Safe to call from the orchestrating
// goroutine (the WS handler) while the tracer goroutine is running —
// the channel is the synchronisation point.
//
// Non-blocking: if the buffer is full (a key held down spamming faster
// than the guest polls) the code is dropped rather than stalling the WS
// reader. Dropping is the right call for input — a slideshow that's
// behind on a held arrow key wants to land on the latest reachable
// slide, not replay a backlog.
func (r *Runner) PushInput(code uint8) {
	select {
	case r.inputCh <- code:
	default:
	}
}

// popInput returns the next queued key code, or keyNone if the queue is
// empty. Called only from the tracer goroutine (the poll dispatch).
func (r *Runner) popInput() uint8 {
	select {
	case code := <-r.inputCh:
		return code
	default:
		return keyNone
	}
}

// tracerLoop owns the OS thread that did exec.Cmd.Start. All ptrace
// ops live here. The lifecycle is: bootstrap → wait for start command
// → apply setup → run syscall loop → close events channel.
func (r *Runner) tracerLoop(stubBytes []byte, bootErr chan<- error) {
	runtime.LockOSThread()
	// Intentionally not unlocked: the thread is destroyed when the
	// goroutine returns, which is exactly the cleanup we want.

	// Single defer covers all exit paths (bootstrap failure, pre-Run
	// close, post-Run close, natural session end).
	defer func() {
		// Signal the periodic MemUpdate ticker to stop AND join its
		// goroutine before closing eventsCh. Without the join the
		// ticker's `select { send_to_eventsCh, <-tickerStop }` can
		// observe the send case becoming "ready for evaluation" (Go
		// makes no ordering guarantees on which case fires when
		// multiple ready cases exist) and then panic when
		// `close(eventsCh)` lands mid-pick.
		close(r.tickerStop)
		r.tickerWg.Wait()
		if r.cmd != nil && r.cmd.Process != nil {
			_ = r.cmd.Process.Kill() // no-op if already dead
			var ws syscall.WaitStatus
			_, _ = syscall.Wait4(r.pid, &ws, 0, nil) // reap
		}
		if r.mem != nil {
			_ = r.mem.f.Close()
		}
		if r.perfFd != -1 {
			_ = syscall.Close(r.perfFd)
		}
		close(r.eventsCh)
		close(r.done)
	}()

	if err := r.bootstrap(stubBytes); err != nil {
		bootErr <- err
		return
	}
	bootErr <- nil

	// Wait for the run command, or for Close to cancel us.
	var msg startMsg
	select {
	case msg = <-r.startCh:
	case <-r.closeCh:
		return
	}

	r.mode = msg.mode
	if r.mode == "" {
		r.mode = proto.ModeHost
	}
	// r.handlers is used in both modes: trap mode reads it to dispatch
	// signals locally; host mode reads it to decide whether to take a
	// (potentially expensive) memory snapshot before forwarding a
	// signal — known-handled signals don't need one because the
	// kernel will dispatch into the guest's handler and the child
	// stays alive.
	r.handlers = make(map[uint8]uint32)
	// Always materialise the trampoline. trap mode uses it as the
	// rt_sigreturn landing pad; both modes need the CD 80 at offset 5
	// as the syscall site for mov-only ABI mmap_request injection.
	// Writing it unconditionally keeps the two callers honest about
	// the trampoline's presence (no mode-conditional foot-gun).
	if err := r.mem.WriteAt(trapTrampolineAddr, trapTrampolineBytes); err != nil {
		r.emitFault(fmt.Sprintf("write syscall/restorer trampoline: %v", err))
		return
	}

	// Apply setup (memory + regs) from the start command.
	var regs regs32
	if err := ptraceGetRegs32(r.pid, &regs); err != nil {
		r.emitFault(fmt.Sprintf("get i386 regs (init): %v", err))
		return
	}
	if r.loadElfPlan != nil {
		// Large-deck handover: map + write the ELF's PT_LOAD segments
		// (out-of-arena ones get a dynamic mmap first), then set EIP to
		// the ELF entry and ESP to the start message's stack top. The
		// trampoline is already written above, so applyElfPlan's
		// mmap injection has a valid syscall site.
		if err := r.applyElfPlan(r.loadElfPlan, &regs); err != nil {
			r.emitFault(fmt.Sprintf("apply ELF plan: %v", err))
			return
		}
		regs.Eip = r.loadElfPlan.entry
		regs.Esp = msg.stackTop
	} else if msg.withCtx {
		// Reservations come first. They cover address ranges the
		// guest's mov-only ABI mmap_request handler already mapped
		// on the sender — invisible in Regions when those pages
		// were still all-zero at snapshot time (the sparse-region
		// walk skips zero pages). Without this, the canvas demo's
		// post-set_video_mode handover SIGSEGVs on its first
		// pixel write because the FB page was never mapped here.
		// Regions that overlap a reservation are still safe: their
		// mmap below re-maps the page (MAP_FIXED, fresh zero) and
		// the region bytes get written on top — same net result.
		for _, res := range msg.ctx.Reservations {
			if regionFitsStaticGuest(res.Addr, res.Size) {
				continue
			}
			if err := r.mmapRegionForLoadContext(res.Addr, res.Size, &regs); err != nil {
				r.emitFault(fmt.Sprintf(
					"mmap context reservation 0x%x..0x%x: %v",
					res.Addr, res.Addr+res.Size, err))
				return
			}
		}
		for _, region := range msg.ctx.Regions {
			// Regions outside the stub's static guestRegions
			// (canvas framebuffers from a wasm snapshot, etc.) need a
			// dynamic mmap before /proc/PID/mem can write them. Same
			// mechanism the mov-only ABI mmap_request uses at runtime;
			// applying it here at LoadContext time lets the receiving
			// engine accept snapshots whose memory map is wider than
			// what the stub statically reserves.
			if !regionFitsStaticGuest(region.Addr, uint32(len(region.Bytes))) {
				if err := r.mmapRegionForLoadContext(region.Addr, uint32(len(region.Bytes)), &regs); err != nil {
					r.emitFault(fmt.Sprintf(
						"mmap context region 0x%x..0x%x: %v",
						region.Addr, region.Addr+uint32(len(region.Bytes)), err))
					return
				}
			}
			if err := r.mem.WriteAt(region.Addr, region.Bytes); err != nil {
				r.emitFault(fmt.Sprintf("write context region 0x%x: %v", region.Addr, err))
				return
			}
		}
		regs.Eax = msg.ctx.Regs.Eax
		regs.Ebx = msg.ctx.Regs.Ebx
		regs.Ecx = msg.ctx.Regs.Ecx
		regs.Edx = msg.ctx.Regs.Edx
		regs.Esi = msg.ctx.Regs.Esi
		regs.Edi = msg.ctx.Regs.Edi
		regs.Ebp = msg.ctx.Regs.Ebp
		regs.Esp = msg.ctx.Regs.Esp
		regs.Eip = msg.ctx.Regs.Eip
		regs.Eflags = msg.ctx.Regs.Eflags
	} else {
		regs.Eip = msg.entry
		regs.Esp = msg.stackTop
	}
	if err := ptraceSetRegs32(r.pid, &regs); err != nil {
		r.emitFault(fmt.Sprintf("set i386 regs (init): %v", err))
		return
	}

	// Start the periodic MemUpdate ticker, if the caller asked for
	// one. tracerLoop's defer joins via `tickerWg.Wait()` before
	// closing eventsCh so the ticker can't panic on a closed
	// channel. The LoadElf path carries its cadence on the Runner
	// (r.memUpdateIntervalMs) rather than the start message, since the
	// server kicks it with the plain Run entry point.
	memUpdateInterval := msg.memUpdateInterval
	if r.loadElfPlan != nil && r.memUpdateIntervalMs > 0 {
		memUpdateInterval = time.Duration(r.memUpdateIntervalMs) * time.Millisecond
	}
	if memUpdateInterval > 0 {
		r.memUpdateEnabled = true
		r.tickerWg.Add(1)
		go func() {
			defer r.tickerWg.Done()
			r.memUpdateTicker(memUpdateInterval)
		}()
	}

	r.syscallLoop(&regs)
}

// memUpdateTicker runs alongside the tracer goroutine and emits one
// `proto.MemUpdate` every `interval`. **No SIGSTOP, no ptrace stop**:
// the snapshot reads `/proc/PID/mem` from this goroutine while the
// guest keeps executing. A small amount of tearing is OK — the
// canvas / progressive-display consumer keeps each frame; the next
// tick fully overwrites it. The trade-off (vs the SIGSTOP-based
// design) is consistency: a snapshot taken while the guest is mid-
// scanline-write may show half a row in the old state and half in
// the new. For movie86's canvas pane that looks fine.
//
// Sends to the shared `eventsCh` are serialised against the tracer
// goroutine's terminal-event sends by an unbuffered-channel race;
// since both sides eventually progress, whichever wins delivery
// first is fine. `Close()` short-circuits via `closeCh`.
func (r *Runner) memUpdateTicker(interval time.Duration) {
	t := time.NewTicker(interval)
	defer t.Stop()
	for {
		select {
		case <-t.C:
			regions, err := r.snapshotMemory()
			if err != nil {
				// Best-effort: snapshot can fail mid-session if the
				// guest is reading a page that just got remapped or
				// /proc/PID/mem hit a transient EAGAIN. Skip the tick
				// rather than tearing down the whole session.
				continue
			}
			// Sample the retired-insn counter best-effort; a transient
			// read failure (or a perfFd that never opened) just yields
			// 0 here so the frontend sees a frozen-ish counter for
			// that tick instead of dropping the whole MemUpdate.
			var insns uint64
			if r.perfFd != -1 {
				if n, perfErr := readInsnCount(r.perfFd); perfErr == nil {
					insns = n
				}
			}
			select {
			case r.eventsCh <- proto.MemUpdate{Regions: regions, Insns: insns}:
			case <-r.closeCh:
				return
			case <-r.tickerStop:
				return
			}
		case <-r.closeCh:
			return
		case <-r.tickerStop:
			return
		}
	}
}

func (r *Runner) bootstrap(stubBytes []byte) error {
	// Stage the stub in a memfd and execve it via /proc/self/fd/N.
	const mfdCloexec = 1
	fd, err := memfdCreate("turbo86-stub", mfdCloexec)
	if err != nil {
		return fmt.Errorf("memfd_create: %w", err)
	}
	if _, err := syscall.Write(fd, stubBytes); err != nil {
		_ = syscall.Close(fd)
		return fmt.Errorf("write stub to memfd: %w", err)
	}

	cmd := exec.Command(fmt.Sprintf("/proc/self/fd/%d", fd))
	cmd.SysProcAttr = &syscall.SysProcAttr{Ptrace: true}
	if err := cmd.Start(); err != nil {
		_ = syscall.Close(fd)
		return fmt.Errorf("exec stub: %w", err)
	}
	_ = syscall.Close(fd)
	r.cmd = cmd
	r.pid = cmd.Process.Pid

	// Initial stop: Go's Ptrace=true makes the child PTRACE_TRACEME
	// then execve, and the kernel stops it at execve.
	var ws syscall.WaitStatus
	if _, err := syscall.Wait4(r.pid, &ws, 0, nil); err != nil {
		return fmt.Errorf("wait initial execve stop: %w", err)
	}
	if !ws.Stopped() {
		return fmt.Errorf("expected initial execve stop, got status %v", ws)
	}
	// TRACESYSGOOD: syscall stops use SIGTRAP|0x80 so we can distinguish
	//   them from real SIGTRAPs (which are reserved for tracer-owned
	//   int3 breakpoints).
	// EXITKILL: if this tracer dies, the kernel sends SIGKILL to the
	//   tracee. Without it, a crashed turbo86 host would orphan the
	//   guest as a normal process — and the guest is executing
	//   untrusted bytes, so anything it runs would no longer be
	//   filtered by the bridge.
	const ptraceOExitkill = 0x00100000
	if err := syscall.PtraceSetOptions(r.pid, syscall.PTRACE_O_TRACESYSGOOD|ptraceOExitkill); err != nil {
		return fmt.Errorf("set ptrace options: %w", err)
	}

	// Let the stub run its setup (mmap RWX region + stack, then
	// kill(self, SIGSTOP)). Wait for the SIGSTOP.
	if err := syscall.PtraceCont(r.pid, 0); err != nil {
		return fmt.Errorf("cont (stub setup): %w", err)
	}
	if _, err := syscall.Wait4(r.pid, &ws, 0, nil); err != nil {
		return fmt.Errorf("wait stub SIGSTOP: %w", err)
	}
	if !ws.Stopped() || ws.StopSignal() != syscall.SIGSTOP {
		return fmt.Errorf("expected stub SIGSTOP, got status %v", ws)
	}

	memFile, err := os.OpenFile(fmt.Sprintf("/proc/%d/mem", r.pid), os.O_RDWR, 0)
	if err != nil {
		return fmt.Errorf("open /proc/%d/mem: %w", r.pid, err)
	}
	r.mem = &procMem{f: memFile}

	// Open a perf_event_open retired-instruction counter on the child
	// so MemUpdate can carry a native instruction count. Soft-fail:
	// when the kernel rejects (e.g. `perf_event_paranoid > 2` in a
	// locked-down container), `r.perfFd` stays -1 and the ticker
	// emits Insns=0. We don't bubble the error up — the session
	// should run without the counter, just with worse-looking cards.
	if fd, perfErr := openInsnCounter(r.pid); perfErr == nil {
		r.perfFd = fd
	}
	return nil
}

func (r *Runner) emitFault(reason string) {
	r.emitFinalMemUpdate()
	r.eventsCh <- proto.Fault{Reason: reason}
}

// emitFinalMemUpdate flushes one last MemUpdate so a progressive-display
// consumer mirrors the guest's final frame at session end. Best-effort
// and only for sessions that opted into periodic MemUpdate (interval >
// 0) — RunOnce-style sessions keep their exact terminal event sequence.
// Callers must already be at a ptrace stop (the snapshot reads guest
// memory); the two call sites — CALL_EXIT dispatch and emitFault — both
// run while the child is stopped. A nil mem / failed-or-empty snapshot
// just skips, so a setup-time fault (no guest memory yet) is harmless.
func (r *Runner) emitFinalMemUpdate() {
	if !r.memUpdateEnabled || r.mem == nil {
		return
	}
	regions, err := r.snapshotMemory()
	if err != nil || len(regions) == 0 {
		return
	}
	r.eventsCh <- proto.MemUpdate{Regions: regions}
}

// syscallPending holds the runner's state between a syscall-entry stop
// and the matching exit stop. Two flavors:
//
//   - Emulated: the entry suppressed the kernel call (orig_eax = -1)
//     and remembers the synthetic return value the bridge computed.
//     At exit we overwrite eax with that value.
//   - Passthrough: the kernel actually runs the syscall. The exit stop
//     still fires, but there's nothing for us to do — we just continue.
//
// `expectingExit` distinguishes "next syscall stop is the exit of an
// in-flight syscall" from "next syscall stop is a fresh entry".
type syscallPending struct {
	expectingExit bool
	overwriteEax  bool   // true for emulated, false for passthrough
	returnValue   uint32 // only meaningful when overwriteEax is true
}

// isForwardableSignal returns true for signals that should be delivered
// to the child via PTRACE_SYSCALL(pid, sig) so the guest's own handler
// (registered via rt_sigaction passthrough) can run. SIGTRAP is
// excluded — it's reserved for tracer-owned breakpoints (future int3
// library bridging). Uncatchable signals (SIGKILL) and job-control
// (SIGSTOP/SIGCONT/...) aren't appropriate to forward; they fall to the
// Paused path.
func isForwardableSignal(sig syscall.Signal) bool {
	switch sig {
	case syscall.SIGILL, syscall.SIGSEGV, syscall.SIGBUS,
		syscall.SIGFPE, syscall.SIGPIPE,
		syscall.SIGUSR1, syscall.SIGUSR2:
		return true
	}
	return false
}

// syscallLoop drives the child through PTRACE_SYSCALL entry/exit pairs:
// entry stops route through the bridge; the bridge either emulates (we
// suppress the real syscall and return a synthetic value at the exit
// stop), passes through (kernel runs the real syscall), or terminates
// the session. Signal stops either forward the signal to the guest
// (so its registered handler runs) or fall to the Paused path.
// pausedSnapshot is captured at a forwardable signal stop *before* the
// signal is delivered to the guest. Held in case the kernel kills the
// child (no handler registered), so the resulting Paused event can
// still carry the regs/memory state at the moment of the fault. If the
// guest's handler runs successfully, the snapshot is discarded on the
// next stop (the child is alive, the snapshot would be stale).
type pausedSnapshot struct {
	regs    proto.Regs
	regions []proto.MemRegion
	signal  uint8
}

// abiCall describes a decoded mov-only ABI invocation:
//
//	mov [imm32], al     (opcode A2, 5 bytes) — 8-bit  argument in AL
//	mov [imm32], eax    (opcode A3, 5 bytes) — 32-bit argument in EAX
//
// where imm32 lies inside `[abiBase, abiBase + abiPageSize)`. The call
// number is the page offset (`imm32 - abiBase`), and the argument is
// extracted from the source register according to the opcode.
//
// Restricting to the absolute-address mov forms (A2/A3) keeps the
// classifier honest: real bug-faults at register-indirect movs whose
// destination happens to point into the ABI page won't get
// misclassified as host calls — there's no instruction to decode an
// argument from. The mov-only ABI's published convention is that
// guests use A2/A3 specifically, so this is by design, not a limitation.
type abiCall struct {
	num     uint16
	arg     uint32
	insnLen uint8
}

// classifyAbi inspects a SIGSEGV stop and decides whether it's a
// mov-only ABI invocation. Returns the decoded call if so, or
// (zero, false) for a real fault that should follow the existing
// Paused / signal-forward path.
func classifyAbi(regs *regs32, mem *procMem) (abiCall, bool) {
	var buf [5]byte
	if err := mem.ReadAt(regs.Eip, buf[:]); err != nil {
		return abiCall{}, false
	}
	target := uint32(buf[1]) | uint32(buf[2])<<8 | uint32(buf[3])<<16 | uint32(buf[4])<<24
	if target < abiBase || target >= abiBase+abiPageSize {
		return abiCall{}, false
	}
	num := uint16(target - abiBase)
	switch buf[0] {
	case 0xA2: // mov [imm32], al
		return abiCall{num: num, arg: regs.Eax & 0xFF, insnLen: 5}, true
	case 0xA3: // mov [imm32], eax
		return abiCall{num: num, arg: regs.Eax, insnLen: 5}, true
	}
	return abiCall{}, false
}

// dispatchAbi handles an ABI call: emits the corresponding Outbound
// event and advances EIP past the faulting mov so the guest resumes
// at the next instruction. Returns false (with a side-effect emitFault)
// for unknown call numbers so a typo in the guest's ABI use surfaces
// loudly rather than silently consuming the fault.
func (r *Runner) dispatchAbi(call abiCall, regs *regs32) bool {
	switch call.num {
	case abiCallSetVideoMode:
		r.eventsCh <- proto.VideoMode{Mode: uint8(call.arg)}
	case abiCallMmapRequest:
		return r.handleMmapRequest(call, regs)
	case abiCallPollInput:
		// Poll for one pending input event. The guest's written value
		// (the trigger) is ignored; we pop one key code off the input
		// queue (keyNone if empty) and hand it back in EAX — the same
		// "return through EAX" shape abiCallWrite uses. Keys arrive from
		// the frontend over the wire as proto.KeyInput; the EIP-advance
		// + SetRegs at the bottom of the switch writes EAX back.
		regs.Eax = uint32(r.popInput())
	case abiCallWrite:
		// Mirrors the int 0x80 SYS_write ABI: fd in ebx, buf in ecx,
		// len in edx. eax (the "value" the guest wrote to trigger the
		// call) is conventionally 4 = SYS_write but isn't checked
		// here — the call number already says "this is a write".
		if !r.handleAbiWrite(regs) {
			return false
		}
	case abiCallExit:
		// Mirrors `int 0x80 / SYS_exit` semantics: emit the Exit event
		// and stop the syscall loop. EIP isn't advanced because the
		// session ends here — the next instruction never runs. Flush a
		// final frame first (no-op unless MemUpdate was enabled) so the
		// canvas reflects the guest's last paint before it exits.
		r.emitFinalMemUpdate()
		r.eventsCh <- proto.Exit{Code: int32(call.arg)}
		return false
	default:
		r.emitFault(fmt.Sprintf("unknown mov-only ABI call 0x%03x at EIP=0x%x", call.num, regs.Eip))
		return false
	}
	regs.Eip += uint32(call.insnLen)
	if err := ptraceSetRegs32(r.pid, regs); err != nil {
		r.emitFault(fmt.Sprintf("set regs after ABI dispatch: %v", err))
		return false
	}
	return true
}

// regionFitsStaticGuest reports whether [addr, addr+size) lies entirely
// inside one of the stub's static guestRegions. Used by LoadContext to
// decide which snapshot regions need a dynamic mmap before write.
func regionFitsStaticGuest(addr, size uint32) bool {
	for _, gr := range guestRegions {
		if addr >= gr.addr && addr+size <= gr.addr+gr.size {
			return true
		}
	}
	return false
}

// mmapRegionForLoadContext page-aligns the requested range, injects an
// mmap2 syscall via ptrace, and records the new region in extraRegions
// so the snapshot path picks it up too. Used during LoadContext setup
// to extend the address space for canvas FB regions that the stub
// doesn't statically map.
//
// Reuses the runtime ABI's injectSyscall helper — same trampoline,
// same ptrace mechanics. Only difference is *when* it's called (init
// vs mid-execution); the child is stopped in both cases.
func (r *Runner) mmapRegionForLoadContext(addr, size uint32, regs *regs32) error {
	r.extraRegionsMu.RLock()
	if len(r.extraRegions) >= mmapMaxRegions {
		r.extraRegionsMu.RUnlock()
		return fmt.Errorf("too many dynamic regions (cap=%d)", mmapMaxRegions)
	}
	r.extraRegionsMu.RUnlock()
	pageAddr := addr & mmapAddrMask
	pageEnd := (addr + size + 0xFFF) & mmapAddrMask
	if pageEnd <= pageAddr {
		return fmt.Errorf("region size 0x%x wraps", size)
	}
	pageSize := pageEnd - pageAddr
	ret, err := r.injectSyscall(regs, sysMmap2,
		pageAddr, pageSize, mmapProtRWX, mmapFlagsFixed, ^uint32(0), 0)
	if err != nil {
		return err
	}
	if ret != pageAddr {
		return fmt.Errorf("mmap returned 0x%x, asked for 0x%x", ret, pageAddr)
	}
	r.extraRegionsMu.Lock()
	r.extraRegions = append(r.extraRegions, struct{ addr, size uint32 }{pageAddr, pageSize})
	r.extraRegionsMu.Unlock()
	return nil
}

// handleAbiWrite reads the int-0x80-style write args from regs
// (fd=ebx, buf=ecx, len=edx), copies bytes from /proc/PID/mem, and
// emits Outbound{Stdout/Stderr}. Bad fd → Fault; mid-stream memory
// read failure → partial Stdout/Stderr followed by Fault, mirroring
// what the bridge's int 0x80 path would do.
//
// Returns true on success (caller advances EIP), false on failure
// (handler has already emitted Fault and aborted the session).
func (r *Runner) handleAbiWrite(regs *regs32) bool {
	fd := regs.Ebx
	bufAddr := regs.Ecx
	length := regs.Edx
	if fd != 1 && fd != 2 {
		r.emitFault(fmt.Sprintf("mov-only ABI write: unsupported fd=%d", fd))
		return false
	}
	if length == 0 {
		// Successful zero-byte write — no event needed, just advance.
		regs.Eax = 0
		return true
	}
	buf := make([]byte, length)
	if err := r.mem.ReadAt(bufAddr, buf); err != nil {
		r.emitFault(fmt.Sprintf("mov-only ABI write: read /proc/PID/mem at 0x%x..0x%x: %v",
			bufAddr, bufAddr+length, err))
		return false
	}
	if fd == 1 {
		r.eventsCh <- proto.Stdout{Bytes: buf}
	} else {
		r.eventsCh <- proto.Stderr{Bytes: buf}
	}
	regs.Eax = length
	return true
}

// handleMmapRequest unpacks the (addr, size) pair the guest packed into
// EAX, injects an `mmap2` syscall via ptrace, records the new region so
// snapshots include it, and advances EIP past the faulting mov.
//
// On any failure (cap reached, syscall rejected, mmap returned a
// different addr than requested), emits a Fault — the guest can't make
// progress without the region it asked for, and silent partial success
// would let the next mov into that range fault confusingly.
func (r *Runner) handleMmapRequest(call abiCall, regs *regs32) bool {
	r.extraRegionsMu.RLock()
	full := len(r.extraRegions) >= mmapMaxRegions
	r.extraRegionsMu.RUnlock()
	if full {
		r.emitFault(fmt.Sprintf(
			"mov-only ABI mmap_request: too many dynamic regions (cap=%d)", mmapMaxRegions))
		return false
	}
	addr := call.arg & mmapAddrMask
	pages := (call.arg & mmapSizeMask) + 1
	size := pages << 12
	ret, err := r.injectSyscall(regs, sysMmap2,
		addr, size, mmapProtRWX, mmapFlagsFixed, ^uint32(0), 0)
	if err != nil {
		r.emitFault(fmt.Sprintf("mmap_request inject: %v", err))
		return false
	}
	if ret != addr {
		r.emitFault(fmt.Sprintf(
			"mmap_request: kernel mapped 0x%x, asked for 0x%x (size=0x%x)", ret, addr, size))
		return false
	}
	r.extraRegionsMu.Lock()
	r.extraRegions = append(r.extraRegions, struct{ addr, size uint32 }{addr, size})
	r.extraRegionsMu.Unlock()

	regs.Eip += uint32(call.insnLen)
	if err := ptraceSetRegs32(r.pid, regs); err != nil {
		r.emitFault(fmt.Sprintf("set regs after mmap_request: %v", err))
		return false
	}
	return true
}

// injectSyscall executes an i386 syscall in the stopped child by
// hijacking EIP onto the existing `int 0x80` site inside the trap
// trampoline (`trapTrampolineAddr + 5`), driving the ptrace
// entry/exit-stop pair, and restoring the pre-injection register
// state. Returns the syscall return value (kernel writes it back
// into EAX at the exit stop).
//
// Caller's `*regs` is restored to the pre-injection values; the
// caller is responsible for advancing EIP / writing any post-call
// state via ptraceSetRegs32.
//
// Must be called only from inside an existing ptrace stop on the
// tracer goroutine — driving PTRACE_SYSCALL from anywhere else would
// race with the outer syscallLoop.
func (r *Runner) injectSyscall(regs *regs32, num uint32, args ...uint32) (uint32, error) {
	saved := *regs

	regs.Eip = trapTrampolineAddr + 5 // points at the CD 80 in the trampoline
	regs.Eax = num
	regs.OrigEax = num
	if len(args) > 0 {
		regs.Ebx = args[0]
	}
	if len(args) > 1 {
		regs.Ecx = args[1]
	}
	if len(args) > 2 {
		regs.Edx = args[2]
	}
	if len(args) > 3 {
		regs.Esi = args[3]
	}
	if len(args) > 4 {
		regs.Edi = args[4]
	}
	if len(args) > 5 {
		regs.Ebp = args[5]
	}
	if err := ptraceSetRegs32(r.pid, regs); err != nil {
		return 0, fmt.Errorf("set regs (syscall inject): %w", err)
	}

	// Drive the entry/exit-stop pair. PTRACE_O_TRACESYSGOOD is on, so
	// stops arrive with (SIGTRAP | 0x80); anything else here is a
	// surprise we abort on.
	var ws syscall.WaitStatus
	for stop := 0; stop < 2; stop++ {
		if err := syscall.PtraceSyscall(r.pid, 0); err != nil {
			return 0, fmt.Errorf("PTRACE_SYSCALL during inject: %w", err)
		}
		if _, err := syscall.Wait4(r.pid, &ws, 0, nil); err != nil {
			return 0, fmt.Errorf("wait during inject: %w", err)
		}
		if !ws.Stopped() {
			return 0, fmt.Errorf("inject: child not stopped: %v", ws)
		}
		if sig := ws.StopSignal(); sig != syscallTrap {
			return 0, fmt.Errorf("inject: expected syscall-stop, got signal %d", sig)
		}
	}

	if err := ptraceGetRegs32(r.pid, regs); err != nil {
		return 0, fmt.Errorf("get regs (syscall return): %w", err)
	}
	ret := regs.Eax

	// Restore caller's regs (kernel-side) so the post-inject state is
	// indistinguishable from "we were never here". The caller is
	// responsible for any deliberate state changes (EIP advance, etc.).
	*regs = saved
	if err := ptraceSetRegs32(r.pid, regs); err != nil {
		return 0, fmt.Errorf("set regs (syscall restore): %w", err)
	}
	return ret, nil
}

func (r *Runner) capturePausedSnapshot(sig syscall.Signal) (pausedSnapshot, error) {
	var snap pausedSnapshot
	var rs regs32
	if err := ptraceGetRegs32(r.pid, &rs); err != nil {
		return snap, err
	}
	regions, err := r.snapshotMemory()
	if err != nil {
		return snap, err
	}
	return pausedSnapshot{regs: protoRegs(&rs), regions: regions, signal: uint8(sig)}, nil
}

func (r *Runner) syscallLoop(regs *regs32) {
	var ws syscall.WaitStatus
	var pending syscallPending
	nextSignal := 0                  // signal to deliver on the next PTRACE_SYSCALL resume
	var heldSnapshot *pausedSnapshot // held across a signal forward in case the child dies

	for {
		if err := syscall.PtraceSyscall(r.pid, nextSignal); err != nil {
			r.emitFault(fmt.Sprintf("PTRACE_SYSCALL: %v", err))
			return
		}
		nextSignal = 0
		if _, err := syscall.Wait4(r.pid, &ws, 0, nil); err != nil {
			r.emitFault(fmt.Sprintf("wait syscall stop: %v", err))
			return
		}
		if ws.Exited() {
			r.emitFault(fmt.Sprintf("child exited unexpectedly (status %d)", ws.ExitStatus()))
			return
		}
		if ws.Signaled() {
			// Forwarded signal had no handler; kernel killed the child.
			// Emit Paused with the snapshot we took before forwarding,
			// if any (rare for it to be missing — would mean the kill
			// came from somewhere other than a forwarded signal).
			s := uint8(ws.Signal())
			ev := proto.Paused{
				Signal: s,
				Reason: fmt.Sprintf("guest killed by signal %d (no handler)", s),
			}
			if heldSnapshot != nil {
				ev.Regs = heldSnapshot.regs
				ev.Regions = heldSnapshot.regions
			}
			r.eventsCh <- ev
			return
		}
		if !ws.Stopped() {
			r.emitFault(fmt.Sprintf("unexpected wait status %v", ws))
			return
		}
		// Child is alive at a stop; any held snapshot is stale.
		heldSnapshot = nil

		if sig := ws.StopSignal(); sig != syscallTrap {
			if sig == syscall.SIGTRAP {
				// Plain SIGTRAP (not SIGTRAP|0x80) is reserved for
				// tracer-owned traps — int3 breakpoints will use this
				// when library-call bridging lands. Unexpected here.
				r.emitFault("unexpected SIGTRAP (reserved for tracer)")
				return
			}
			if isForwardableSignal(sig) {
				// mov-only ABI: an unmapped write into [abiBase, abiBase+
				// abiPageSize) is a host call disguised as a SIGSEGV.
				// Check before mode-specific handler dispatch so the
				// behaviour is identical in ModeHost and ModeTrap (the
				// runner owns the ABI page regardless of which signal-
				// dispatch policy is in effect).
				if sig == syscall.SIGSEGV {
					if err := ptraceGetRegs32(r.pid, regs); err != nil {
						r.emitFault(fmt.Sprintf("get regs (ABI probe): %v", err))
						return
					}
					if call, ok := classifyAbi(regs, r.mem); ok {
						if !r.dispatchAbi(call, regs) {
							return
						}
						continue
					}
				}
				// In trap mode the runner owns signal dispatch: look up
				// the guest-registered handler in r.handlers, save the
				// pre-signal regs on r.signalRegs for a future
				// rt_sigreturn, and redirect EIP into the handler. The
				// signal is NOT delivered to the kernel (nextSignal=0)
				// — turbo86 just edits the child's state directly.
				if r.mode == proto.ModeTrap {
					if handlerAddr, ok := r.handlers[uint8(sig)]; ok {
						if err := ptraceGetRegs32(r.pid, regs); err != nil {
							r.emitFault(fmt.Sprintf("get regs (trap signal): %v", err))
							return
						}
						// Save the pre-signal regs for rt_sigreturn. ESP is
						// the original, so when the handler eventually
						// returns and rt_sigreturn restores from this
						// snapshot, the stack is back to where it was.
						r.signalRegs = append(r.signalRegs, *regs)

						// Push the restorer trampoline address onto the
						// guest stack so a returning handler `ret`s into
						// it and triggers rt_sigreturn. Matches what the
						// kernel does for host-mode signal delivery
						// (modulo the full sigframe layout we don't need
						// for handlers that don't read ucontext).
						newEsp := regs.Esp - 4
						addr := uint32(trapTrampolineAddr)
						addrBuf := [4]byte{
							byte(addr),
							byte(addr >> 8),
							byte(addr >> 16),
							byte(addr >> 24),
						}
						if err := r.mem.WriteAt(newEsp, addrBuf[:]); err != nil {
							r.emitFault(fmt.Sprintf("push trap-mode restorer: %v", err))
							return
						}
						regs.Esp = newEsp
						regs.Eip = handlerAddr
						if err := ptraceSetRegs32(r.pid, regs); err != nil {
							r.emitFault(fmt.Sprintf("set regs (trap signal): %v", err))
							return
						}
						continue
					}
					// No registered handler in trap mode → fall through
					// to Paused with the snapshot.
					snap, err := r.capturePausedSnapshot(sig)
					if err != nil {
						r.emitFault(fmt.Sprintf("snapshot at unhandled trap-mode signal: %v", err))
						return
					}
					r.eventsCh <- proto.Paused{
						Regs:    snap.regs,
						Regions: snap.regions,
						Signal:  snap.signal,
						Reason:  fmt.Sprintf("trap-mode: no handler for signal %d", sig),
					}
					return
				}
				// Host mode: only snapshot when the kernel will probably
				// kill the child for lack of a handler — otherwise the
				// handler runs to completion and the snapshot is just
				// wasted I/O. For movfuscator-style guests that fire
				// SIGILL on every dispatch this is the difference
				// between ~18 MiB/signal and nothing/signal.
				if _, hasHandler := r.handlers[uint8(sig)]; !hasHandler {
					snap, err := r.capturePausedSnapshot(sig)
					if err != nil {
						r.emitFault(fmt.Sprintf("snapshot at signal forward: %v", err))
						return
					}
					heldSnapshot = &snap
				}
				nextSignal = int(sig)
				continue
			}
			// Periodic MemUpdate path: if this SIGSTOP is one we sent
			// ourselves for a memory snapshot (CAS 1→0 on
			// snapshotPending), grab the regions, emit MemUpdate, and
			// resume the guest without delivering the signal. The
			// alternative — sending Paused here — would terminate the
			// session, which is the right thing for a user-initiated
			// Pause but wrong for "tick periodically while still
			// running". CAS distinguishes ours from a Pause()-sent or
			// truly external SIGSTOP.
			// Not forwardable (job-control, etc.) — surface as Paused.
			// (No special-case for periodic SIGSTOP — that path no
			// longer exists; the MemUpdate ticker reads memory async
			// without stopping the tracee.)
			snap, err := r.capturePausedSnapshot(sig)
			if err != nil {
				r.emitFault(fmt.Sprintf("snapshot at non-forwardable signal: %v", err))
				return
			}
			r.eventsCh <- proto.Paused{
				Regs:    snap.regs,
				Regions: snap.regions,
				Signal:  snap.signal,
				Reason:  fmt.Sprintf("guest received non-forwardable signal %d", sig),
			}
			return
		}

		// Syscall-trap stop. Distinguish entry from exit via pending.
		if pending.expectingExit {
			if pending.overwriteEax {
				if err := ptraceGetRegs32(r.pid, regs); err != nil {
					r.emitFault(fmt.Sprintf("get i386 regs (exit stop): %v", err))
					return
				}
				regs.Eax = pending.returnValue
				if err := ptraceSetRegs32(r.pid, regs); err != nil {
					r.emitFault(fmt.Sprintf("set i386 regs (exit stop): %v", err))
					return
				}
			}
			// Passthrough: nothing to write back — the kernel already
			// set eax to whatever the real syscall returned.
			pending = syscallPending{}
			continue
		}

		// Entry stop: read syscall number + args, route through bridge.
		if err := ptraceGetRegs32(r.pid, regs); err != nil {
			r.emitFault(fmt.Sprintf("get i386 regs (entry stop): %v", err))
			return
		}

		// In trap mode, the runner intercepts the signal-disposition
		// syscalls itself (instead of letting the bridge passthrough
		// to the kernel) so guest signal handling stays entirely
		// inside turbo86 — matching movie86's software-modeled signal
		// semantics for migration parity.
		if r.mode == proto.ModeTrap {
			if handled, retVal, err := r.handleTrapModeSyscall(regs); handled {
				if err != nil {
					r.emitFault(fmt.Sprintf("trap-mode syscall %d: %v", regs.OrigEax, err))
					return
				}
				regs.OrigEax = suppressedSyscall
				if err := ptraceSetRegs32(r.pid, regs); err != nil {
					r.emitFault(fmt.Sprintf("set regs (trap-mode suppress): %v", err))
					return
				}
				pending = syscallPending{expectingExit: true, overwriteEax: true, returnValue: retVal}
				continue
			}
		}

		// Host mode: rt_sigaction passes through to the kernel, but we
		// still want to know which signals have a guest handler so the
		// signal-stop branch can skip the 18 MiB memory snapshot when
		// the kernel will dispatch into a registered handler (snapshot
		// is only needed if the child is about to die because no
		// handler is installed).
		if r.mode == proto.ModeHost && regs.OrigEax == sysRtSigaction {
			r.sniffHostSigaction(regs)
		}

		args := bridge.SyscallArgs{
			Eax: regs.OrigEax,
			Ebx: regs.Ebx,
			Ecx: regs.Ecx,
			Edx: regs.Edx,
			Esi: regs.Esi,
			Edi: regs.Edi,
			Ebp: regs.Ebp,
		}
		result, brErr := bridge.HandleSyscall(args, r.mem)
		if result.Event != nil {
			r.eventsCh <- result.Event
		}
		if brErr != nil {
			return
		}
		switch result.Action {
		case bridge.ActionExit, bridge.ActionFault:
			return
		case bridge.ActionResume:
			// Suppress the kernel syscall: orig_eax=-1 makes the kernel
			// return -ENOSYS; we overwrite eax with our synthetic value
			// at the upcoming exit stop.
			regs.OrigEax = suppressedSyscall
			if err := ptraceSetRegs32(r.pid, regs); err != nil {
				r.emitFault(fmt.Sprintf("set i386 regs (suppress syscall): %v", err))
				return
			}
			pending = syscallPending{expectingExit: true, overwriteEax: true, returnValue: result.Return}
		case bridge.ActionPassthrough:
			// Let the kernel run the real syscall. orig_eax is unchanged
			// (the original number); no eax overwrite at exit.
			pending = syscallPending{expectingExit: true}
		}
	}
}

// Syscall numbers the trap-mode path intercepts (kept in sync with
// bridge/bridge.go's passthrough allowlist).
const (
	sysRtSigreturn   = 173
	sysRtSigaction   = 174
	sysRtSigprocmask = 175
)

// handleTrapModeSyscall intercepts the signal-disposition syscalls in
// trap mode so the runner — not the kernel — owns guest signal state.
// Returns (handled, returnValue, err). When handled is true, the
// caller suppresses the kernel syscall and sets up the exit stop to
// overwrite eax with returnValue.
func (r *Runner) handleTrapModeSyscall(regs *regs32) (bool, uint32, error) {
	switch regs.OrigEax {
	case sysRtSigaction:
		// rt_sigaction(signum, &act, &oldact, sigsetsize)
		// ebx = signum, ecx = &act (may be NULL for pure-query call),
		// edx = &oldact (may be NULL).
		signum := uint8(regs.Ebx)

		// Snapshot the pre-call handler so a non-NULL oldact reads
		// the *previous* disposition (sigaction semantics: the new
		// handler replaces the old, and the caller can retrieve the
		// old one even when also setting a new one).
		prevHandler, prevSet := r.handlers[signum]

		// If act is non-NULL, install a new handler from sa_handler
		// (offset 0 in both kernel k_sigaction and userspace struct
		// sigaction). SIG_DFL (0) and SIG_IGN (1) mean "no handler" —
		// drop the entry so r.handlers reflects "is a real handler
		// registered" rather than "did the guest ever call sigaction".
		if regs.Ecx != 0 {
			var buf [4]byte
			if err := r.mem.ReadAt(regs.Ecx, buf[:]); err != nil {
				return true, 0, fmt.Errorf("read sa_handler at 0x%x: %w", regs.Ecx, err)
			}
			handler := uint32(buf[0]) | uint32(buf[1])<<8 | uint32(buf[2])<<16 | uint32(buf[3])<<24
			if handler <= 1 {
				delete(r.handlers, signum)
			} else {
				r.handlers[signum] = handler
			}
		}

		// If oldact is non-NULL, fill the *kernel* struct k_sigaction
		// (20 bytes on i386: sa_handler/sa_flags/sa_restorer/sa_mask[2])
		// — matching the byte count the kernel writes in host mode.
		// Writing the 140-byte userspace layout here would clobber
		// adjacent guest memory and diverge from host-mode behavior.
		// We only track sa_handler; sa_flags/sa_restorer/sa_mask stay
		// zero. libc-using guests handle the 20↔140 layout translation
		// on their side, exactly as they do for host-mode passthrough.
		if regs.Edx != 0 {
			var out [20]byte
			if prevSet {
				out[0] = byte(prevHandler)
				out[1] = byte(prevHandler >> 8)
				out[2] = byte(prevHandler >> 16)
				out[3] = byte(prevHandler >> 24)
			}
			if err := r.writeMem(regs.Edx, out[:]); err != nil {
				return true, 0, fmt.Errorf("write oldact at 0x%x: %w", regs.Edx, err)
			}
		}
		return true, 0, nil

	case sysRtSigreturn:
		// Restore the regs we saved at the matching signal stop. The
		// syscall's "return value" is what we wrote at exit, but
		// rt_sigreturn replaces *all* regs from the sigframe — so we
		// overwrite the regs entirely here, and the exit-stop logic's
		// eax write is harmless (eax also comes from saved regs).
		if len(r.signalRegs) == 0 {
			return true, 0, fmt.Errorf("rt_sigreturn with empty signal stack")
		}
		top := len(r.signalRegs) - 1
		saved := r.signalRegs[top]
		r.signalRegs = r.signalRegs[:top]
		// Preserve OrigEax = suppressedSyscall (caller will set it
		// right after we return), then write the saved register state
		// out. The exit-stop code will load regs again before its eax
		// overwrite, but we got there first — set everything now.
		*regs = saved
		regs.OrigEax = suppressedSyscall
		// returnValue is the saved eax (already in regs.Eax via *regs = saved)
		return true, saved.Eax, nil

	case sysRtSigprocmask:
		// No-op: turbo86 sees every signal stop regardless of the
		// guest's nominal mask, so changing the mask doesn't affect
		// what gets dispatched.
		return true, 0, nil
	}
	return false, 0, nil
}

// collectEvents drains an events channel into an ordered slice. The
// channel must be closed for this to return. Used by the convenience
// wrappers RunOnce and RunWithContext.
func collectEvents(events <-chan proto.Outbound) ([]proto.Outbound, error) {
	var out []proto.Outbound
	for ev := range events {
		out = append(out, ev)
	}
	return out, nil
}
