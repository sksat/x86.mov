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

// Start sets the guest's initial EIP and ESP and begins execution.
// Sent after the Code messages that supply the entry-point's code.
type Start struct {
	Entry    uint32 `json:"entry"`
	StackTop uint32 `json:"stack_top"`
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

// Context is a transferable snapshot of guest execution: enough state
// for either engine to pick up from where the other left off. The
// receiver loads memory regions first, then sets Regs, then resumes
// execution (and may keep streaming additional Code messages after
// LoadContext).
//
// v1 ships the simplest workable schema — full memory in Regions, no
// signal disposition, no generation counter. Both can be added later
// without breaking existing payloads (additive JSON fields).
type Context struct {
	Regs    Regs        `json:"regs"`
	Regions []MemRegion `json:"regions"`
}

// LoadContext hands a Context to the runner: write each MemRegion into
// guest memory, set Regs, and continue. Used for engine migration —
// e.g., the frontend takes a Context out of movie86 and hands it to
// turbo86 for the hot path.
type LoadContext struct {
	Context Context `json:"context"`
}

func (LoadContext) inboundKind() string { return "load_context" }

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

// Fault reports a non-recoverable runner error (unsupported syscall, guest
// fault, memory violation, ...) and ends the session.
type Fault struct {
	Reason string `json:"reason"`
}

func (Fault) outboundKind() string { return "fault" }

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
	default:
		return nil, fmt.Errorf("proto: unknown Outbound type %q", probe.Type)
	}
}
