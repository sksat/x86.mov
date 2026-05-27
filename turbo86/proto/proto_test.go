package proto

import (
	"reflect"
	"strings"
	"testing"
)

func TestInboundRoundTrip(t *testing.T) {
	tests := []struct {
		name string
		msg  Inbound
	}{
		{
			"Code typical",
			Code{Offset: 0x08048000, Bytes: []byte{0xB8, 0x01, 0x00, 0x00, 0x00}},
		},
		{
			"Code zero offset",
			Code{Offset: 0, Bytes: []byte{0x90}},
		},
		{
			"Start typical",
			Start{Entry: 0x08048000, StackTop: 0xBFFF0000},
		},
		{
			"Start zero",
			Start{Entry: 0, StackTop: 0},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			data, err := MarshalInbound(tt.msg)
			if err != nil {
				t.Fatalf("MarshalInbound: %v", err)
			}
			got, err := UnmarshalInbound(data)
			if err != nil {
				t.Fatalf("UnmarshalInbound(%s): %v", data, err)
			}
			if !reflect.DeepEqual(got, tt.msg) {
				t.Errorf("round-trip mismatch:\n  got:  %#v\n  want: %#v\n  wire: %s", got, tt.msg, data)
			}
		})
	}
}

func TestOutboundRoundTrip(t *testing.T) {
	tests := []struct {
		name string
		msg  Outbound
	}{
		{"Stdout typical", Stdout{Bytes: []byte("hello")}},
		{"Stderr typical", Stderr{Bytes: []byte("warning")}},
		{"Exit zero", Exit{Code: 0}},
		{"Exit nonzero", Exit{Code: 42}},
		{"Fault message", Fault{Reason: "unknown syscall 99"}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			data, err := MarshalOutbound(tt.msg)
			if err != nil {
				t.Fatalf("MarshalOutbound: %v", err)
			}
			got, err := UnmarshalOutbound(data)
			if err != nil {
				t.Fatalf("UnmarshalOutbound(%s): %v", data, err)
			}
			if !reflect.DeepEqual(got, tt.msg) {
				t.Errorf("round-trip mismatch:\n  got:  %#v\n  want: %#v\n  wire: %s", got, tt.msg, data)
			}
		})
	}
}

func TestInboundTypeDiscriminatorIsPresent(t *testing.T) {
	data, err := MarshalInbound(Start{Entry: 1, StackTop: 2})
	if err != nil {
		t.Fatalf("MarshalInbound: %v", err)
	}
	if !strings.Contains(string(data), `"type":"start"`) {
		t.Errorf("expected `\"type\":\"start\"` in wire form, got: %s", data)
	}
}

func TestOutboundTypeDiscriminatorIsPresent(t *testing.T) {
	data, err := MarshalOutbound(Exit{Code: 42})
	if err != nil {
		t.Fatalf("MarshalOutbound: %v", err)
	}
	if !strings.Contains(string(data), `"type":"exit"`) {
		t.Errorf("expected `\"type\":\"exit\"` in wire form, got: %s", data)
	}
}

func TestUnmarshalInboundUnknownType(t *testing.T) {
	_, err := UnmarshalInbound([]byte(`{"type":"nonsense"}`))
	if err == nil {
		t.Fatal("expected error for unknown inbound type, got nil")
	}
	if !strings.Contains(err.Error(), "nonsense") {
		t.Errorf("error should mention the unknown type, got: %v", err)
	}
}

func TestUnmarshalOutboundUnknownType(t *testing.T) {
	_, err := UnmarshalOutbound([]byte(`{"type":"nonsense"}`))
	if err == nil {
		t.Fatal("expected error for unknown outbound type, got nil")
	}
	if !strings.Contains(err.Error(), "nonsense") {
		t.Errorf("error should mention the unknown type, got: %v", err)
	}
}

// fakeInbound is a stand-in for "an Inbound the marshal switch doesn't know."
// Embedding the interface satisfies the Inbound contract at compile time;
// inboundKind() would panic if called but the marshal switch's default
// branch fires before reaching it.
type fakeInbound struct{ Inbound }

func TestMarshalInboundUnknownType(t *testing.T) {
	_, err := MarshalInbound(fakeInbound{})
	if err == nil {
		t.Fatal("expected error for unknown Inbound type, got nil")
	}
	if !strings.Contains(err.Error(), "fakeInbound") {
		t.Errorf("error should mention the unknown type, got: %v", err)
	}
}

type fakeOutbound struct{ Outbound }

func TestMarshalOutboundUnknownType(t *testing.T) {
	_, err := MarshalOutbound(fakeOutbound{})
	if err == nil {
		t.Fatal("expected error for unknown Outbound type, got nil")
	}
	if !strings.Contains(err.Error(), "fakeOutbound") {
		t.Errorf("error should mention the unknown type, got: %v", err)
	}
}
