package bridge

import (
	"errors"
	"reflect"
	"strings"
	"testing"

	"github.com/sksat/x86.mov/turbo86/proto"
)

// memMock is a fixed-region in-memory GuestMemory for tests.
type memMock struct {
	base uint32
	data []byte
	err  error
}

func (m *memMock) ReadAt(addr uint32, buf []byte) error {
	if m.err != nil {
		return m.err
	}
	if addr < m.base || uint64(addr)+uint64(len(buf)) > uint64(m.base)+uint64(len(m.data)) {
		return errors.New("memMock: out of range")
	}
	copy(buf, m.data[addr-m.base:])
	return nil
}

func TestHandleSyscall_Exit(t *testing.T) {
	res, err := HandleSyscall(SyscallArgs{Eax: 1, Ebx: 42}, nil)
	if err != nil {
		t.Fatalf("HandleSyscall: %v", err)
	}
	if res.Action != ActionExit {
		t.Errorf("Action: got %v want ActionExit", res.Action)
	}
	if !reflect.DeepEqual(res.Event, proto.Exit{Code: 42}) {
		t.Errorf("Event: got %#v want proto.Exit{Code: 42}", res.Event)
	}
}

func TestHandleSyscall_ExitNonZero(t *testing.T) {
	res, err := HandleSyscall(SyscallArgs{Eax: 1, Ebx: 0xFFFFFFFF}, nil) // ebx as signed = -1
	if err != nil {
		t.Fatalf("HandleSyscall: %v", err)
	}
	if want := (proto.Exit{Code: -1}); !reflect.DeepEqual(res.Event, want) {
		t.Errorf("Event: got %#v want %#v", res.Event, want)
	}
}

func TestHandleSyscall_WriteStdout(t *testing.T) {
	mem := &memMock{base: 0x1000, data: []byte("hello")}
	res, err := HandleSyscall(SyscallArgs{Eax: 4, Ebx: 1, Ecx: 0x1000, Edx: 5}, mem)
	if err != nil {
		t.Fatalf("HandleSyscall: %v", err)
	}
	if res.Action != ActionResume {
		t.Errorf("Action: got %v want ActionResume", res.Action)
	}
	if res.Return != 5 {
		t.Errorf("Return: got %d want 5", res.Return)
	}
	if !reflect.DeepEqual(res.Event, proto.Stdout{Bytes: []byte("hello")}) {
		t.Errorf("Event: got %#v want Stdout{hello}", res.Event)
	}
}

func TestHandleSyscall_WriteStderr(t *testing.T) {
	mem := &memMock{base: 0x2000, data: []byte("oops")}
	res, err := HandleSyscall(SyscallArgs{Eax: 4, Ebx: 2, Ecx: 0x2000, Edx: 4}, mem)
	if err != nil {
		t.Fatalf("HandleSyscall: %v", err)
	}
	if !reflect.DeepEqual(res.Event, proto.Stderr{Bytes: []byte("oops")}) {
		t.Errorf("Event: got %#v want Stderr{oops}", res.Event)
	}
}

func TestHandleSyscall_WriteZeroLength(t *testing.T) {
	res, err := HandleSyscall(SyscallArgs{Eax: 4, Ebx: 1, Ecx: 0xDEADBEEF, Edx: 0}, nil)
	if err != nil {
		t.Fatalf("HandleSyscall: %v", err)
	}
	if res.Action != ActionResume {
		t.Errorf("Action: got %v want ActionResume", res.Action)
	}
	if res.Return != 0 {
		t.Errorf("Return: got %d want 0", res.Return)
	}
	if !reflect.DeepEqual(res.Event, proto.Stdout{Bytes: []byte{}}) {
		t.Errorf("Event: got %#v want Stdout{} (empty)", res.Event)
	}
}

func TestHandleSyscall_WriteBadFd(t *testing.T) {
	res, err := HandleSyscall(SyscallArgs{Eax: 4, Ebx: 7, Ecx: 0x1000, Edx: 5}, nil)
	if err != nil {
		t.Fatalf("HandleSyscall: %v", err)
	}
	if res.Action != ActionFault {
		t.Errorf("Action: got %v want ActionFault", res.Action)
	}
	fault, ok := res.Event.(proto.Fault)
	if !ok {
		t.Fatalf("Event: got %T want proto.Fault", res.Event)
	}
	if !strings.Contains(fault.Reason, "7") {
		t.Errorf("fault reason should mention fd 7: %q", fault.Reason)
	}
}

func TestHandleSyscall_WriteTooLarge(t *testing.T) {
	res, err := HandleSyscall(SyscallArgs{Eax: 4, Ebx: 1, Ecx: 0x1000, Edx: 1 << 30}, nil)
	if err != nil {
		t.Fatalf("HandleSyscall: %v", err)
	}
	if res.Action != ActionFault {
		t.Errorf("Action: got %v want ActionFault", res.Action)
	}
	if _, ok := res.Event.(proto.Fault); !ok {
		t.Errorf("Event: got %T want proto.Fault", res.Event)
	}
}

func TestHandleSyscall_WriteMemoryError(t *testing.T) {
	mem := &memMock{err: errors.New("ptrace read failed")}
	res, err := HandleSyscall(SyscallArgs{Eax: 4, Ebx: 1, Ecx: 0x1000, Edx: 5}, mem)
	if err == nil {
		t.Fatal("expected error from memory failure, got nil")
	}
	if res.Action != ActionFault {
		t.Errorf("Action: got %v want ActionFault", res.Action)
	}
	if _, ok := res.Event.(proto.Fault); !ok {
		t.Errorf("Event: got %T want proto.Fault", res.Event)
	}
}

func TestHandleSyscall_Unknown(t *testing.T) {
	res, err := HandleSyscall(SyscallArgs{Eax: 999}, nil)
	if err != nil {
		t.Fatalf("HandleSyscall: %v", err)
	}
	if res.Action != ActionFault {
		t.Errorf("Action: got %v want ActionFault", res.Action)
	}
	fault, ok := res.Event.(proto.Fault)
	if !ok {
		t.Fatalf("Event: got %T want proto.Fault", res.Event)
	}
	if !strings.Contains(fault.Reason, "999") {
		t.Errorf("fault reason should mention syscall 999: %q", fault.Reason)
	}
}
