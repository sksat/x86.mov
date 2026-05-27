// Package bridge translates intercepted i386 Linux syscalls into protocol
// events for the frontend. It is the analogue of movie86's SysHost trait,
// but used at ptrace-stop time rather than emulator-step time.
//
// The package is intentionally pure: no ptrace, no goroutines, no I/O.
// Callers supply the SyscallArgs (read from the child via PTRACE_GETREGSET)
// and a GuestMemory accessor; the bridge returns the event to emit and
// what the runner should do next (resume, exit, fault).
package bridge

import (
	"fmt"

	"github.com/sksat/x86.mov/turbo86/proto"
)

// SyscallArgs is the i386 Linux syscall register snapshot. eax is the
// syscall number; ebx/ecx/edx/esi/edi/ebp are args 1..6.
type SyscallArgs struct {
	Eax uint32
	Ebx uint32
	Ecx uint32
	Edx uint32
	Esi uint32
	Edi uint32
	Ebp uint32
}

// GuestMemory abstracts the guest's address space. ReadAt copies
// len(buf) bytes starting at guest virtual address addr into buf.
// Production uses /proc/PID/mem; tests use an in-memory mock.
type GuestMemory interface {
	ReadAt(addr uint32, buf []byte) error
}

// Action tells the runner what to do after the bridge handles a syscall.
type Action int

const (
	// ActionResume: write Result.Return into the child's eax (skipping
	// the real syscall) and let it run again.
	ActionResume Action = iota
	// ActionExit: the guest called exit(); end the session.
	ActionExit
	// ActionFault: a non-recoverable condition (unknown syscall, bad
	// argument, memory access failure); emit the Fault event and stop.
	ActionFault
)

// Result is what HandleSyscall returns to the runner.
type Result struct {
	// Event is the Outbound message to send the frontend. Always non-nil.
	Event proto.Outbound
	// Return is the value to write to the child's eax. Only meaningful
	// when Action == ActionResume.
	Return uint32
	// Action is what to do next.
	Action Action
}

// maxWriteBytes bounds a single write(2)'s buffer size. Anything larger
// is a bug or DoS attempt; the runner shouldn't allocate gigabytes on
// behalf of a misbehaving guest. Linux itself caps at 0x7FFFF000.
const maxWriteBytes = 64 * 1024 * 1024

// HandleSyscall translates one guest syscall into a Result.
//
// mem may be nil only when the syscall doesn't touch guest memory
// (e.g., exit). It MUST be non-nil for memory-touching syscalls
// even when their count is zero; callers shouldn't have to know
// which is which.
func HandleSyscall(args SyscallArgs, mem GuestMemory) (Result, error) {
	switch args.Eax {
	case 1: // exit
		return Result{
			Event:  proto.Exit{Code: int32(args.Ebx)},
			Action: ActionExit,
		}, nil
	case 4: // write
		return handleWrite(args, mem)
	default:
		return Result{
			Event:  proto.Fault{Reason: fmt.Sprintf("unsupported syscall eax=%d", args.Eax)},
			Action: ActionFault,
		}, nil
	}
}

func handleWrite(args SyscallArgs, mem GuestMemory) (Result, error) {
	fd, buf, cnt := args.Ebx, args.Ecx, args.Edx

	if fd != 1 && fd != 2 {
		return Result{
			Event:  proto.Fault{Reason: fmt.Sprintf("write to unsupported fd %d", fd)},
			Action: ActionFault,
		}, nil
	}
	if cnt > maxWriteBytes {
		return Result{
			Event:  proto.Fault{Reason: fmt.Sprintf("write count %d exceeds max %d", cnt, maxWriteBytes)},
			Action: ActionFault,
		}, nil
	}

	data := make([]byte, cnt)
	if cnt > 0 {
		if err := mem.ReadAt(buf, data); err != nil {
			return Result{
				Event:  proto.Fault{Reason: fmt.Sprintf("reading write(%d) buffer at 0x%x: %v", fd, buf, err)},
				Action: ActionFault,
			}, fmt.Errorf("read guest buffer: %w", err)
		}
	}

	var ev proto.Outbound
	if fd == 1 {
		ev = proto.Stdout{Bytes: data}
	} else {
		ev = proto.Stderr{Bytes: data}
	}
	return Result{Event: ev, Return: cnt, Action: ActionResume}, nil
}
