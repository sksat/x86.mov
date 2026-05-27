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
	"fmt"
	"io"
	"os"
	"os/exec"
	"runtime"
	"sync"
	"syscall"
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
func snapshotMemory(mem *procMem) ([]proto.MemRegion, error) {
	var out []proto.MemRegion

	for _, gr := range guestRegions {
		buf := make([]byte, gr.size)
		if err := mem.ReadAt(gr.addr, buf); err != nil {
			return nil, fmt.Errorf("snapshot region 0x%x..0x%x: %w", gr.addr, gr.addr+gr.size, err)
		}
		var i uint32
		for i < gr.size {
			// Skip zero pages.
			for i < gr.size && allZero(buf[i:i+pageSize]) {
				i += pageSize
			}
			if i >= gr.size {
				break
			}
			// Walk the run of non-zero pages.
			runStart := i
			for i < gr.size && !allZero(buf[i:i+pageSize]) {
				i += pageSize
			}
			out = append(out, proto.MemRegion{
				Addr:  gr.addr + runStart,
				Bytes: append([]byte(nil), buf[runStart:i]...),
			})
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

	startCh   chan startMsg
	eventsCh  chan proto.Outbound
	closeCh   chan struct{}
	done      chan struct{}
	closeOnce sync.Once
}

type startMsg struct {
	withCtx  bool
	entry    uint32
	stackTop uint32
	ctx      proto.Context
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
		eventsCh: make(chan proto.Outbound),
		closeCh:  make(chan struct{}),
		done:     make(chan struct{}),
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

// Run sets EIP=entry / ESP=stackTop and enters the syscall-bridge loop.
// Returns a channel that streams Outbound events in order; the channel
// closes when the session ends (Exit / Paused / Fault).
//
// One-shot per Runner: do not call Run or RunWithContext more than once.
func (r *Runner) Run(entry, stackTop uint32) <-chan proto.Outbound {
	r.startCh <- startMsg{entry: entry, stackTop: stackTop}
	return r.eventsCh
}

// RunWithContext writes ctx.Regions into guest memory, sets the full
// reg file from ctx.Regs, then enters the syscall-bridge loop. Same
// channel semantics as Run.
func (r *Runner) RunWithContext(ctx proto.Context) <-chan proto.Outbound {
	r.startCh <- startMsg{withCtx: true, ctx: ctx}
	return r.eventsCh
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
		if r.cmd != nil && r.cmd.Process != nil {
			_ = r.cmd.Process.Kill() // no-op if already dead
			var ws syscall.WaitStatus
			_, _ = syscall.Wait4(r.pid, &ws, 0, nil) // reap
		}
		if r.mem != nil {
			_ = r.mem.f.Close()
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

	// Apply setup (memory + regs) from the start command.
	var regs regs32
	if err := ptraceGetRegs32(r.pid, &regs); err != nil {
		r.emitFault(fmt.Sprintf("get i386 regs (init): %v", err))
		return
	}
	if msg.withCtx {
		for _, region := range msg.ctx.Regions {
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

	r.syscallLoop(&regs)
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
	if err := syscall.PtraceSetOptions(r.pid, syscall.PTRACE_O_TRACESYSGOOD); err != nil {
		return fmt.Errorf("set TRACESYSGOOD: %w", err)
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
	return nil
}

func (r *Runner) emitFault(reason string) {
	r.eventsCh <- proto.Fault{Reason: reason}
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

func (r *Runner) capturePausedSnapshot(sig syscall.Signal) (pausedSnapshot, error) {
	var snap pausedSnapshot
	var rs regs32
	if err := ptraceGetRegs32(r.pid, &rs); err != nil {
		return snap, err
	}
	regions, err := snapshotMemory(r.mem)
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
				// Snapshot the fault state in case the child dies from
				// this signal (no handler), then forward.
				snap, err := r.capturePausedSnapshot(sig)
				if err != nil {
					r.emitFault(fmt.Sprintf("snapshot at signal forward: %v", err))
					return
				}
				heldSnapshot = &snap
				nextSignal = int(sig)
				continue
			}
			// Not forwardable (job-control, etc.) — surface as Paused.
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
