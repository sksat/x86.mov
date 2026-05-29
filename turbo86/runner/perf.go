//go:build linux

package runner

import (
	"encoding/binary"
	"fmt"
	"os"
	"syscall"
	"unsafe"
)

// perf_event_open-driven retired-instruction counter for the guest
// child. Used by `memUpdateTicker` to embed an actual hardware
// instruction count in each `proto.MemUpdate`, so the frontend's
// `total mov / mov per sec` cards reflect native execution rate
// instead of the previously-substituted Outbound event count (which
// was off by orders of magnitude — a guest running at 10⁸ insn/s
// emitted ~10 events/s, making the cards look like the guest had
// slowed down a million-fold after handover).
//
// We hand-write the syscall + struct rather than pulling in
// `golang.org/x/sys/unix` for this single use: keeps `turbo86`'s
// dependency surface to just `coder/websocket`, and the perf ABI is
// stable enough across kernel versions that we don't need the helper.
// See `man 2 perf_event_open` for the wire format.

// sysPerfEventOpen is the syscall number on x86_64. (turbo86 runs as a
// 64-bit tracer of a 32-bit guest; the syscall is invoked from the
// tracer, so the 64-bit number is what we need.)
const sysPerfEventOpen = 298

// perf_event constants we use. Names mirror `<linux/perf_event.h>`.
const (
	perfTypeHardware         = 0
	perfCountHwInstructions  = 1
	perfAttrSizeVer3  uint32 = 96
)

// Bit positions inside the packed `bits` field of perf_event_attr.
// Only the few we actually set are spelled out.
const (
	perfBitDisabled      uint64 = 1 << 0
	perfBitExcludeKernel uint64 = 1 << 5
	perfBitExcludeHv     uint64 = 1 << 6
)

// perfEventAttr mirrors the kernel's `struct perf_event_attr` up to
// `aux_watermark` (version 3, size 96). The kernel reads min(attr.size,
// kernel-known size) bytes, so a v3-sized declaration is forward-
// compatible with newer kernels and accepted by every kernel since 3.14.
//
// Field order and types must match the C struct byte-for-byte; only the
// fields we read or write are individually meaningful, the rest are
// zeroed and the kernel ignores them for our (HW counter, no sample,
// no mmap) use.
type perfEventAttr struct {
	Type         uint32
	Size         uint32
	Config       uint64
	SamplePeriod uint64
	SampleType   uint64
	ReadFormat   uint64
	Bits         uint64
	WakeupEvents uint32
	BpType       uint32
	BpAddr       uint64
	BpLen        uint64
	BranchSample uint64
	SampleRegsU  uint64
	SampleStackU uint32
	ClockId      int32
	SampleRegsI  uint64
	AuxWatermark uint32
	SampleMaxStk uint16
	_            uint16
}

// openInsnCounter opens a hardware retired-instruction counter on the
// given pid. cpu = -1 (count on whatever CPU the task is running on),
// group_fd = -1 (no group), flags = 0. Counter is created in the
// "enabled" state so the moment we PtraceCont the child it starts
// accumulating.
//
// Returns -1 + a sentinel error when perf_event_open isn't allowed
// (e.g. `kernel.perf_event_paranoid` > 2 in unprivileged containers).
// Callers should treat that as "counter unavailable" and emit Insns=0
// on the wire rather than failing the session — the demo still works,
// the frontend just sees no number movement.
func openInsnCounter(pid int) (int, error) {
	attr := perfEventAttr{
		Type:   perfTypeHardware,
		Size:   perfAttrSizeVer3,
		Config: perfCountHwInstructions,
		Bits:   perfBitExcludeKernel | perfBitExcludeHv,
	}
	fd, _, errno := syscall.Syscall6(
		sysPerfEventOpen,
		uintptr(unsafe.Pointer(&attr)),
		uintptr(pid),
		^uintptr(0), // cpu = -1
		^uintptr(0), // group_fd = -1
		0,           // flags
		0,
	)
	if errno != 0 {
		return -1, os.NewSyscallError("perf_event_open", errno)
	}
	return int(fd), nil
}

// readInsnCount returns the cumulative counter value. Reads exactly
// 8 bytes (a single uint64) — the default ReadFormat layout for a
// non-group counter without time-enabled / time-running fields.
func readInsnCount(fd int) (uint64, error) {
	var buf [8]byte
	n, err := syscall.Read(fd, buf[:])
	if err != nil {
		return 0, fmt.Errorf("read perf counter fd=%d: %w", fd, err)
	}
	if n != 8 {
		return 0, fmt.Errorf("short read on perf counter fd=%d: got %d bytes", fd, n)
	}
	return binary.LittleEndian.Uint64(buf[:]), nil
}
