//go:build linux

// Package runner drives the ptraced child stub: spawn, inject guest
// code, set registers, intercept syscalls via PTRACE_SYSEMU, route them
// through the bridge, and collect the resulting protocol events.
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
	"syscall"
	"unsafe"

	"github.com/sksat/x86.mov/turbo86/bridge"
	"github.com/sksat/x86.mov/turbo86/proto"
)

// PTRACE_SYSEMU stops the child at syscall entry and skips kernel
// dispatch entirely; the tracer is responsible for setting eax to the
// syscall's synthetic return value. Not exposed by the Go stdlib.
const ptraceSysEmu = 31

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

// ptraceSysEmuStep is PTRACE_SYSEMU via raw syscall (no Go stdlib wrapper).
func ptraceSysEmuStep(pid int) error {
	_, _, errno := syscall.Syscall6(syscall.SYS_PTRACE, ptraceSysEmu, uintptr(pid), 0, 0, 0, 0)
	if errno != 0 {
		return errno
	}
	return nil
}

// setupFunc runs once the child stub has reached its self-SIGSTOP and
// /proc/PID/mem is open. It writes any initial guest memory and mutates
// regs in place; the runner then writes regs back and enters the
// syscall loop. Used to vary "what to load before running" between the
// fresh-start path (RunOnce) and the engine-migration path
// (RunWithContext).
type setupFunc func(mem *procMem, regs *regs32) error

// RunOnce executes a single guest session starting fresh.
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
	return runWithStub(stubBytes, func(mem *procMem, regs *regs32) error {
		for addr, data := range code {
			if err := mem.WriteAt(addr, data); err != nil {
				return fmt.Errorf("write %d bytes at 0x%x: %w", len(data), addr, err)
			}
		}
		regs.Eip = entry
		regs.Esp = stackTop
		return nil
	})
}

// RunWithContext resumes a guest session from a Context handed off by
// another engine (e.g., movie86). Writes ctx.Regions into guest memory
// and sets the full register file from ctx.Regs (Eax..Edi, Esp, Eip,
// Eflags), then executes through the same syscall-bridge loop.
//
// Same LockOSThread requirement as RunOnce.
func RunWithContext(stubBytes []byte, ctx proto.Context) ([]proto.Outbound, error) {
	return runWithStub(stubBytes, func(mem *procMem, regs *regs32) error {
		for _, r := range ctx.Regions {
			if err := mem.WriteAt(r.Addr, r.Bytes); err != nil {
				return fmt.Errorf("write region %d bytes at 0x%x: %w", len(r.Bytes), r.Addr, err)
			}
		}
		regs.Eax = ctx.Regs.Eax
		regs.Ebx = ctx.Regs.Ebx
		regs.Ecx = ctx.Regs.Ecx
		regs.Edx = ctx.Regs.Edx
		regs.Esi = ctx.Regs.Esi
		regs.Edi = ctx.Regs.Edi
		regs.Ebp = ctx.Regs.Ebp
		regs.Esp = ctx.Regs.Esp
		regs.Eip = ctx.Regs.Eip
		regs.Eflags = ctx.Regs.Eflags
		return nil
	})
}

// runWithStub holds the boilerplate shared between RunOnce and
// RunWithContext: spawn the stub, drive it to its self-SIGSTOP, open
// /proc/PID/mem, invoke setup, then run the syscall-bridge loop until
// Exit or Fault.
func runWithStub(stubBytes []byte, setup setupFunc) ([]proto.Outbound, error) {
	// Stage the stub in a memfd and execve it via /proc/self/fd/N.
	const mfdCloexec = 1
	fd, err := memfdCreate("turbo86-stub", mfdCloexec)
	if err != nil {
		return nil, fmt.Errorf("memfd_create: %w", err)
	}
	if _, err := syscall.Write(fd, stubBytes); err != nil {
		_ = syscall.Close(fd)
		return nil, fmt.Errorf("write stub to memfd: %w", err)
	}

	cmd := exec.Command(fmt.Sprintf("/proc/self/fd/%d", fd))
	cmd.SysProcAttr = &syscall.SysProcAttr{Ptrace: true}
	if err := cmd.Start(); err != nil {
		_ = syscall.Close(fd)
		return nil, fmt.Errorf("exec stub: %w", err)
	}
	_ = syscall.Close(fd)
	pid := cmd.Process.Pid

	// Best-effort cleanup. Kill on an already-dead process is harmless.
	defer func() {
		_ = cmd.Process.Kill()
		_, _ = cmd.Process.Wait()
	}()

	// Initial stop: Go's Ptrace=true makes the child PTRACE_TRACEME then
	// execve, and the kernel stops it at execve.
	var ws syscall.WaitStatus
	if _, err := syscall.Wait4(pid, &ws, 0, nil); err != nil {
		return nil, fmt.Errorf("wait initial execve stop: %w", err)
	}
	if !ws.Stopped() {
		return nil, fmt.Errorf("expected initial execve stop, got status %v", ws)
	}
	if err := syscall.PtraceSetOptions(pid, syscall.PTRACE_O_TRACESYSGOOD); err != nil {
		return nil, fmt.Errorf("set TRACESYSGOOD: %w", err)
	}

	// Let the stub run its setup (mmap RWX region + stack, then
	// kill(self, SIGSTOP)). Wait for the SIGSTOP.
	if err := syscall.PtraceCont(pid, 0); err != nil {
		return nil, fmt.Errorf("cont (stub setup): %w", err)
	}
	if _, err := syscall.Wait4(pid, &ws, 0, nil); err != nil {
		return nil, fmt.Errorf("wait stub SIGSTOP: %w", err)
	}
	if !ws.Stopped() || ws.StopSignal() != syscall.SIGSTOP {
		return nil, fmt.Errorf("expected stub SIGSTOP, got status %v", ws)
	}

	// Open /proc/PID/mem for fast bulk memory I/O.
	memFile, err := os.OpenFile(fmt.Sprintf("/proc/%d/mem", pid), os.O_RDWR, 0)
	if err != nil {
		return nil, fmt.Errorf("open /proc/%d/mem: %w", pid, err)
	}
	defer memFile.Close()
	mem := &procMem{f: memFile}

	// Snapshot current regs (so setup can preserve fields it doesn't
	// touch — e.g., CS/SS that the stub already established).
	var regs regs32
	if err := ptraceGetRegs32(pid, &regs); err != nil {
		return nil, fmt.Errorf("get i386 regs (init): %w", err)
	}
	if err := setup(mem, &regs); err != nil {
		return nil, fmt.Errorf("setup: %w", err)
	}
	if err := ptraceSetRegs32(pid, &regs); err != nil {
		return nil, fmt.Errorf("set i386 regs (init): %w", err)
	}

	// Syscall loop: PTRACE_SYSEMU stops the child *before* each syscall.
	// We translate via bridge.HandleSyscall, set rax to the synthetic
	// return value, and resume.
	var events []proto.Outbound
	for {
		if err := ptraceSysEmuStep(pid); err != nil {
			return events, fmt.Errorf("PTRACE_SYSEMU: %w", err)
		}
		if _, err := syscall.Wait4(pid, &ws, 0, nil); err != nil {
			return events, fmt.Errorf("wait syscall stop: %w", err)
		}
		if ws.Exited() {
			events = append(events, proto.Fault{
				Reason: fmt.Sprintf("child exited unexpectedly (status %d)", ws.ExitStatus()),
			})
			return events, nil
		}
		if !ws.Stopped() {
			events = append(events, proto.Fault{
				Reason: fmt.Sprintf("unexpected wait status %v", ws),
			})
			return events, nil
		}
		if sig := ws.StopSignal(); sig != syscallTrap {
			// SIGSEGV, SIGILL (e.g. the stub's ud2 trap), etc.
			events = append(events, proto.Fault{
				Reason: fmt.Sprintf("guest stopped on signal %d (want syscall-trap)", sig),
			})
			return events, nil
		}

		if err := ptraceGetRegs32(pid, &regs); err != nil {
			return events, fmt.Errorf("get i386 regs (syscall stop): %w", err)
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
		result, brErr := bridge.HandleSyscall(args, mem)
		events = append(events, result.Event)
		if brErr != nil {
			return events, brErr
		}
		switch result.Action {
		case bridge.ActionExit, bridge.ActionFault:
			return events, nil
		case bridge.ActionResume:
			regs.Eax = result.Return
			if err := ptraceSetRegs32(pid, &regs); err != nil {
				return events, fmt.Errorf("set i386 regs (return value): %w", err)
			}
		}
	}
}
