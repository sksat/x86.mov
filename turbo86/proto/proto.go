// Package proto defines the wire protocol between turbo86 and its frontend.
//
// All messages are JSON objects with a "type" discriminator field. Inbound
// messages flow frontend → runner; Outbound messages flow runner → frontend.
// Adding a new variant means adding a struct + a kind() method + a case in
// Marshal/Unmarshal and a round-trip test in the same commit.
package proto

import (
	"encoding/json"
	"fmt"
)

// Inbound is a message from the frontend to the runner.
type Inbound interface {
	inboundKind() string
}

// Code appends raw guest machine code bytes at Offset (a guest virtual
// address) into the guest's executable memory region. Multiple Code
// messages can stream code in before Start. Post-Start writes are
// allowed but not synchronized with the running guest.
type Code struct {
	Offset uint32 `json:"offset"`
	Bytes  []byte `json:"bytes"`
}

func (Code) inboundKind() string { return "code" }

// Mode picks between the two execution policies turbo86 supports.
//
//   - "host":  rt_sigaction/rt_sigreturn/rt_sigprocmask pass through to
//     the kernel; signal stops are forwarded so the guest's kernel-
//     registered handler runs. Simple, native semantics.
//   - "trap":  turbo86 owns signal dispatch. rt_sigaction is emulated
//     (handler address recorded in-runner); signal stops change EIP to
//     the recorded handler directly; rt_sigreturn restores from the
//     in-runner saved-regs stack. Migration-parity with movie86.
//
// The empty string defaults to "host" — existing protocol callers stay
// on the original behavior without changes.
type Mode string

const (
	ModeHost Mode = "host"
	ModeTrap Mode = "trap"
)

// Start sets the guest's initial EIP and ESP and begins execution.
// Sent after the Code messages that supply the entry-point's code.
//
// `MemUpdateIntervalMs` opts the session into periodic mid-run
// memory snapshots — turbo86 will SIGSTOP the guest every N ms,
// snapshot the sparse non-zero pages, emit `MemUpdate{Regions}`, and
// resume. 0 (the default) disables it; the session emits no mid-run
// memory events, matching the original behavior. Typical value for a
// browser frontend driving a canvas: 100ms.
type Start struct {
	Entry               uint32 `json:"entry"`
	StackTop            uint32 `json:"stack_top"`
	Mode                Mode   `json:"mode,omitempty"`
	MemUpdateIntervalMs uint32 `json:"mem_update_interval_ms,omitempty"`
}

func (Start) inboundKind() string { return "start" }

// Regs is the canonical i386 guest-visible register state for engine
// migration. Held common between turbo86 and movie86 so a snapshot from
// one can resume on the other. Segment registers and OrigEax are
// intentionally omitted — they're either constant in 32-bit user mode
// (segments) or transient syscall machinery (OrigEax).
type Regs struct {
	Eax    uint32 `json:"eax"`
	Ebx    uint32 `json:"ebx"`
	Ecx    uint32 `json:"ecx"`
	Edx    uint32 `json:"edx"`
	Esi    uint32 `json:"esi"`
	Edi    uint32 `json:"edi"`
	Ebp    uint32 `json:"ebp"`
	Esp    uint32 `json:"esp"`
	Eip    uint32 `json:"eip"`
	Eflags uint32 `json:"eflags"`
}

// MemRegion is one contiguous chunk of guest memory in a Context.
// Multiple MemRegions can carry disjoint or overlapping ranges; the
// receiver applies them in order.
type MemRegion struct {
	Addr  uint32 `json:"addr"`
	Bytes []byte `json:"bytes"`
}

// Reservation declares an address range that must be mapped on the
// receiver before the guest resumes, even when the sender's snapshot
// carries no bytes for it (e.g. an all-zero framebuffer page the
// sparse-region walk skipped). Concretely the guest may have already
// issued a mov-only ABI `mmap_request` on the sender — that side
// effect is invisible in Regs/Regions, so we record it here so the
// receiver can replay the mmap. Addr and Size are in guest bytes;
// the receiver page-aligns internally.
type Reservation struct {
	Addr uint32 `json:"addr"`
	Size uint32 `json:"size"`
}

// Context is a transferable snapshot of guest execution: enough state
// for either engine to pick up from where the other left off. The
// receiver loads memory regions first, then sets Regs, then resumes
// execution (and may keep streaming additional Code messages after
// LoadContext).
//
// v1 ships the simplest workable schema — full memory in Regions, no
// signal disposition, no generation counter. Both can be added later
// without breaking existing payloads (additive JSON fields).
//
// Reservations are additive: pages the receiver must mmap before
// resuming, even though they carry no bytes in Regions. Needed for
// ABI mmap_request side effects (e.g. a mode-13h framebuffer that
// was still all-zero when the snapshot was taken).
type Context struct {
	Regs         Regs          `json:"regs"`
	Regions      []MemRegion   `json:"regions"`
	Reservations []Reservation `json:"reservations,omitempty"`
}

// LoadContext hands a Context to the runner: write each MemRegion into
// guest memory, set Regs, and continue. Used for engine migration —
// e.g., the frontend takes a Context out of movie86 and hands it to
// turbo86 for the hot path. Mode picks the execution policy; empty
// defaults to "host".
type LoadContext struct {
	Context             Context `json:"context"`
	Mode                Mode    `json:"mode,omitempty"`
	MemUpdateIntervalMs uint32  `json:"mem_update_interval_ms,omitempty"`
}

func (LoadContext) inboundKind() string { return "load_context" }

// Stop asks the runner to terminate the current session — useful for
// "cancel" UI without dropping the WebSocket. Server-side, this sends
// SIGKILL to the guest child (no payload needed): the kill unblocks
// the tracer's wait4 even for guests stuck in no-syscall tight loops,
// which is the headline use case (interrupting a runaway dispatch
// loop like movfuscator's master_loop). The session then ends with a
// Paused{Signal: SIGKILL} followed by normal WS closure.
type Stop struct{}

func (Stop) inboundKind() string { return "stop" }

// Pause asks the runner to cooperatively halt the current session and
// emit a Paused Outbound carrying the canonical Context (Regs +
// sparse Regions). This is the engine-handoff trigger: a peer engine
// can take the resulting Context and resume execution via its own
// LoadContext. Server-side, this sends SIGSTOP to the guest child;
// the kernel reports a non-forwardable signal stop, which the
// runner's existing Paused path snapshots regs + memory for. No
// payload — the response data lives entirely in the Paused.
//
// Boundary semantics: pause lands at whatever ptrace-stop granularity
// the child happens to be at — typically an instruction boundary, but
// possibly mid-syscall-trap if SIGSTOP arrives between an entry and
// exit stop. The same caveat applies to the existing signal-driven
// Paused (which fires at the faulting instruction), so peer engines
// already tolerate non-end-of-instruction boundaries.
type Pause struct{}

func (Pause) inboundKind() string { return "pause" }

// MarshalInbound encodes an Inbound as a JSON object with a "type" field.
func MarshalInbound(msg Inbound) ([]byte, error) {
	switch m := msg.(type) {
	case Code:
		return json.Marshal(struct {
			Type string `json:"type"`
			Code
		}{m.inboundKind(), m})
	case Start:
		return json.Marshal(struct {
			Type string `json:"type"`
			Start
		}{m.inboundKind(), m})
	case LoadContext:
		return json.Marshal(struct {
			Type string `json:"type"`
			LoadContext
		}{m.inboundKind(), m})
	case Stop:
		return json.Marshal(struct {
			Type string `json:"type"`
		}{m.inboundKind()})
	case Pause:
		return json.Marshal(struct {
			Type string `json:"type"`
		}{m.inboundKind()})
	default:
		return nil, fmt.Errorf("proto: unknown Inbound type %T", msg)
	}
}

// UnmarshalInbound parses a JSON message with a "type" discriminator
// into the corresponding Inbound variant.
func UnmarshalInbound(data []byte) (Inbound, error) {
	var probe struct {
		Type string `json:"type"`
	}
	if err := json.Unmarshal(data, &probe); err != nil {
		return nil, fmt.Errorf("proto: parsing type discriminator: %w", err)
	}
	switch probe.Type {
	case "code":
		var m Code
		if err := json.Unmarshal(data, &m); err != nil {
			return nil, fmt.Errorf("proto: parsing Code payload: %w", err)
		}
		return m, nil
	case "start":
		var m Start
		if err := json.Unmarshal(data, &m); err != nil {
			return nil, fmt.Errorf("proto: parsing Start payload: %w", err)
		}
		return m, nil
	case "load_context":
		var m LoadContext
		if err := json.Unmarshal(data, &m); err != nil {
			return nil, fmt.Errorf("proto: parsing LoadContext payload: %w", err)
		}
		return m, nil
	case "stop":
		return Stop{}, nil
	case "pause":
		return Pause{}, nil
	default:
		return nil, fmt.Errorf("proto: unknown Inbound type %q", probe.Type)
	}
}

// Outbound is a message from the runner to the frontend.
type Outbound interface {
	outboundKind() string
}

// Stdout reports bytes the guest wrote to fd 1 via write(2).
type Stdout struct {
	Bytes []byte `json:"bytes"`
}

func (Stdout) outboundKind() string { return "stdout" }

// Stderr reports bytes the guest wrote to fd 2 via write(2).
type Stderr struct {
	Bytes []byte `json:"bytes"`
}

func (Stderr) outboundKind() string { return "stderr" }

// Exit reports the guest's exit(2) status. Per Linux convention only the
// low 8 bits are wait-status-meaningful, but the full 32-bit value passed
// through ebx is preserved here.
type Exit struct {
	Code int32 `json:"code"`
}

func (Exit) outboundKind() string { return "exit" }

// Fault reports a non-recoverable condition the runner can't gracefully
// hand off (unsupported syscall, bad memory range on a host operation,
// …) and ends the session. Distinct from Paused: Fault is "give up", a
// receiving engine can't resume usefully from this.
type Fault struct {
	Reason string `json:"reason"`
}

func (Fault) outboundKind() string { return "fault" }

// Paused reports that the guest stopped at a recoverable boundary the
// current engine doesn't handle natively — typically a synchronous
// signal (SIGSEGV from the movfuscator dispatch trick, SIGILL from the
// alt master_loop trick, …). Regs + Regions together are enough for a
// peer engine to pick the session up via LoadContext.
//
// Regions is sparse: the runner walks the guest's mmap'd ranges page
// by page and emits only the non-zero pages (merged into runs of
// adjacent non-zero pages). For a freshly-faulted guest this is
// typically a few KiB, vs. the ~18 MiB the dense range would carry.
type Paused struct {
	Regs    Regs        `json:"regs"`
	Regions []MemRegion `json:"regions,omitempty"`
	Signal  uint8       `json:"signal"`
	Reason  string      `json:"reason"`
}

func (Paused) outboundKind() string { return "paused" }

// VideoMode reports that the guest selected a video mode via the
// mov-only ABI (see runner's abi page handling). Replaces the BIOS
// `int 0x10 / AH=0 / AL=mode` convention: the guest writes the mode
// byte to a magic address on the ABI page, the runner intercepts the
// SIGSEGV that the unmapped write produces, surfaces the mode here,
// and resumes the guest past the offending mov. Keeps the "everything
// is a mov" narrative intact across both wasm and turbo86.
type VideoMode struct {
	Mode uint8 `json:"mode"`
}

func (VideoMode) outboundKind() string { return "video_mode" }

// MemUpdate reports a periodic mid-session snapshot of guest memory
// regions. Same sparse `MemRegion` shape Paused uses, but it's an
// *intermediate* event — the session is still running — so a peer
// engine can keep its own view of guest memory in sync for
// progressive display (canvas filling in as a decoder writes pixels,
// etc.) without waiting for terminal Paused / Exit.
//
// Cadence is configured at session start via Start.MemUpdateIntervalMs
// / LoadContext.MemUpdateIntervalMs (default 0 = disabled). While
// enabled, the runner periodically SIGSTOPs the guest, captures the
// non-zero pages, emits one MemUpdate, and resumes. The guest never
// sees the stop — `SIGSTOP` is non-forwardable and the snapshot path
// doesn't dispatch into the guest's signal table.
//
// Insns is the cumulative retired-instruction count for the guest
// process up to the snapshot point, sampled from a
// `perf_event_open(PERF_COUNT_HW_INSTRUCTIONS)` fd opened on the
// child at spawn time. 0 means "counter unavailable" — the runner
// emits 0 when the perf counter never opened (e.g. tight kernel
// `perf_event_paranoid` setting or unprivileged container) so the
// field is always present but optionally meaningful. The frontend
// uses this to display real native instruction counts instead of
// substituting Outbound event counts (which were off by orders of
// magnitude — a guest running at 10⁸ insn/s emitted ~10 events/s).
type MemUpdate struct {
	Regions []MemRegion `json:"regions"`
	Insns   uint64      `json:"insns,omitempty"`
}

func (MemUpdate) outboundKind() string { return "mem_update" }

// MarshalOutbound encodes an Outbound as a JSON object with a "type" field.
func MarshalOutbound(msg Outbound) ([]byte, error) {
	switch m := msg.(type) {
	case Stdout:
		return json.Marshal(struct {
			Type string `json:"type"`
			Stdout
		}{m.outboundKind(), m})
	case Stderr:
		return json.Marshal(struct {
			Type string `json:"type"`
			Stderr
		}{m.outboundKind(), m})
	case Exit:
		return json.Marshal(struct {
			Type string `json:"type"`
			Exit
		}{m.outboundKind(), m})
	case Fault:
		return json.Marshal(struct {
			Type string `json:"type"`
			Fault
		}{m.outboundKind(), m})
	case Paused:
		return json.Marshal(struct {
			Type string `json:"type"`
			Paused
		}{m.outboundKind(), m})
	case VideoMode:
		return json.Marshal(struct {
			Type string `json:"type"`
			VideoMode
		}{m.outboundKind(), m})
	case MemUpdate:
		return json.Marshal(struct {
			Type string `json:"type"`
			MemUpdate
		}{m.outboundKind(), m})
	default:
		return nil, fmt.Errorf("proto: unknown Outbound type %T", msg)
	}
}

// UnmarshalOutbound parses a JSON message with a "type" discriminator
// into the corresponding Outbound variant.
func UnmarshalOutbound(data []byte) (Outbound, error) {
	var probe struct {
		Type string `json:"type"`
	}
	if err := json.Unmarshal(data, &probe); err != nil {
		return nil, fmt.Errorf("proto: parsing type discriminator: %w", err)
	}
	switch probe.Type {
	case "stdout":
		var m Stdout
		if err := json.Unmarshal(data, &m); err != nil {
			return nil, fmt.Errorf("proto: parsing Stdout payload: %w", err)
		}
		return m, nil
	case "stderr":
		var m Stderr
		if err := json.Unmarshal(data, &m); err != nil {
			return nil, fmt.Errorf("proto: parsing Stderr payload: %w", err)
		}
		return m, nil
	case "exit":
		var m Exit
		if err := json.Unmarshal(data, &m); err != nil {
			return nil, fmt.Errorf("proto: parsing Exit payload: %w", err)
		}
		return m, nil
	case "fault":
		var m Fault
		if err := json.Unmarshal(data, &m); err != nil {
			return nil, fmt.Errorf("proto: parsing Fault payload: %w", err)
		}
		return m, nil
	case "paused":
		var m Paused
		if err := json.Unmarshal(data, &m); err != nil {
			return nil, fmt.Errorf("proto: parsing Paused payload: %w", err)
		}
		return m, nil
	case "video_mode":
		var m VideoMode
		if err := json.Unmarshal(data, &m); err != nil {
			return nil, fmt.Errorf("proto: parsing VideoMode payload: %w", err)
		}
		return m, nil
	case "mem_update":
		var m MemUpdate
		if err := json.Unmarshal(data, &m); err != nil {
			return nil, fmt.Errorf("proto: parsing MemUpdate payload: %w", err)
		}
		return m, nil
	default:
		return nil, fmt.Errorf("proto: unknown Outbound type %q", probe.Type)
	}
}
