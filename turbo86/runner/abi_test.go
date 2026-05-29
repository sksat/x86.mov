//go:build linux

package runner

import (
	"reflect"
	"runtime"
	"testing"

	"github.com/sksat/x86.mov/turbo86/proto"
	"github.com/sksat/x86.mov/turbo86/stub"
)

// TestRunOnce_AbiSetVideoMode is the headline mov-only ABI test: the
// guest selects a VGA video mode without `int 0x10` by writing the
// mode byte to a magic address on the runner's ABI page. The runner
// catches the SIGSEGV that the unmapped write produces, decodes the
// faulting `mov [imm32], al`, emits Outbound{VideoMode{Mode: 0x13}},
// advances EIP past the 5-byte mov, and resumes — same flow turbo86
// will use for canvas_mandelbrot once the stubs are switched off the
// BIOS `int 0x10` convention.
//
// Guest:
//
//	B0 13                   mov al, 0x13         ; (2 bytes)
//	A2 10 00 FE 1F          mov [0x1FFE0010], al ; (5 bytes) — ABI set_video_mode
//	B8 01 00 00 00          mov eax, 1           ; SYS_exit
//	BB 00 00 00 00          mov ebx, 0           ; status = 0
//	CD 80                   int 0x80             ; exit(0)
func TestRunOnce_AbiSetVideoMode(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const entry uint32 = 0x08048000
	code := []byte{
		0xB0, 0x13,
		0xA2, 0x10, 0x00, 0xFE, 0x1F,
		0xB8, 0x01, 0x00, 0x00, 0x00,
		0xBB, 0x00, 0x00, 0x00, 0x00,
		0xCD, 0x80,
	}

	events, err := RunOnce(stub.Bytes, map[uint32][]byte{entry: code}, entry, testStackTop)
	if err != nil {
		t.Fatalf("RunOnce: %v", err)
	}
	want := []proto.Outbound{
		proto.VideoMode{Mode: 0x13},
		proto.Exit{Code: 0},
	}
	if !reflect.DeepEqual(events, want) {
		t.Errorf("events:\n  got:  %#v\n  want: %#v", events, want)
	}
}

// TestRunOnce_AbiExit drives an exit through the mov-only ABI: the
// guest packs the exit code into EAX and writes it to call slot 0x0FE.
// The runner emits Exit{code} and tears down the session — same
// observable wire behaviour as the existing `mov eax, 1 ; mov ebx, n
// ; int 0x80` path, but without an `int` in sight. Replaces the last
// `int 0x80` in the toolchain-generated guests (the `_start_llvm.s`
// epilogue and `stubs_movfuscator.s`'s `exit()` wrapper) so a canvas
// ELF can be entirely mov-only.
//
// Guest:
//
//	B8 17 00 00 00      mov eax, 23           ; exit code
//	A3 FE 00 FE 1F      mov [0x1FFE00FE], eax ; ABI exit
func TestRunOnce_AbiExit(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const entry uint32 = 0x08048000
	code := []byte{
		0xB8, 0x17, 0x00, 0x00, 0x00,
		0xA3, 0xFE, 0x00, 0xFE, 0x1F,
	}

	events, err := RunOnce(stub.Bytes, map[uint32][]byte{entry: code}, entry, testStackTop)
	if err != nil {
		t.Fatalf("RunOnce: %v", err)
	}
	want := []proto.Outbound{proto.Exit{Code: 23}}
	if !reflect.DeepEqual(events, want) {
		t.Errorf("events:\n  got:  %#v\n  want: %#v", events, want)
	}
}

// TestRunOnce_AbiLoadContext_AutoMmapsOutOfRangeRegions verifies that
// a LoadContext carrying a region OUTSIDE the stub's static guestRegions
// triggers a dynamic mmap2 before the region's bytes are written via
// /proc/PID/mem. Without it, snapshots from a movie86 wasm Vm with a
// `.fb13h` PT_LOAD at 0xA0000 would fail at LoadContext time with
// `write /proc/PID/mem: input/output error` (the actual symptom of the
// canvas-mandelbrot handover regression #28 set out to fix).
//
// Setup: hand-built guest at 0x08048000 that exits(42). The LoadContext
// carries a SECOND region at 0x00100000 (mode 12h FB address — well
// outside the stub's static mapping) with a small payload. The runner
// must mmap that page and write the payload; the guest then writes back
// a known byte at the same address and exits. Reading the byte back
// proves the auto-mmap worked end-to-end.
func TestRunOnce_AbiLoadContext_AutoMmapsOutOfRangeRegions(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const entry uint32 = 0x08048000
	const fbAddr uint32 = 0x00100000

	// Guest: write 0x42 to [fbAddr], then exit(42).
	//   B0 42                 mov al, 0x42
	//   A2 00 00 10 00        mov [0x00100000], al
	//   B8 01 00 00 00        mov eax, 1
	//   BB 2A 00 00 00        mov ebx, 42
	//   CD 80                 int 0x80
	code := []byte{
		0xB0, 0x42,
		0xA2, 0x00, 0x00, 0x10, 0x00,
		0xB8, 0x01, 0x00, 0x00, 0x00,
		0xBB, 0x2A, 0x00, 0x00, 0x00,
		0xCD, 0x80,
	}
	// FB-region payload (pretend non-zero "snapshot" bytes). 5 bytes,
	// enough to verify the write landed; the rest of the page stays
	// zero after the kernel-supplied anonymous mapping.
	fbPayload := []byte{0xAA, 0xBB, 0xCC, 0xDD, 0xEE}

	r, err := New(stub.Bytes)
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	defer r.Close()
	ch := r.RunWithContextAndMode(proto.Context{
		Regs: proto.Regs{Eip: entry, Esp: testStackTop},
		Regions: []proto.MemRegion{
			{Addr: entry, Bytes: code},
			{Addr: fbAddr, Bytes: fbPayload},
		},
	}, proto.ModeHost)
	var events []proto.Outbound
	for ev := range ch {
		events = append(events, ev)
	}
	want := []proto.Outbound{proto.Exit{Code: 42}}
	if !reflect.DeepEqual(events, want) {
		t.Fatalf("events:\n  got:  %#v\n  want: %#v", events, want)
	}
}

// TestRunOnce_AbiMmapRequest grows the guest's address space at runtime
// via the mov-only ABI: the guest packs an (addr, size) pair into EAX
// and writes it to the mmap_request slot (call 0x020). The runner
// intercepts the SIGSEGV that the unmapped write produces, injects an
// `mmap2(addr, length, RWX, FIXED|ANON|PRIVATE, -1, 0)` syscall into
// the stopped child via ptrace, advances EIP past the faulting mov,
// and resumes. Subsequent writes into the freshly-mapped range
// succeed without further faults.
//
// This is the canvas_mandelbrot enabler: FB regions at `0xA0000` etc.
// land in this scheme without hard-coding addresses into the stub.
//
// Packing: eax[31:12] = page-aligned addr >> 12, eax[11:0] = pages - 1.
//
// Guest:
//
//	B8 03 00 10 00      mov eax, 0x00100003     ; addr=0x00100000, pages=4
//	A3 20 00 FE 1F      mov [0x1FFE0020], eax   ; ABI mmap_request
//	B0 4F               mov al, 'O'
//	A2 00 00 10 00      mov [0x00100000], al    ; write into new region
//	B0 4B               mov al, 'K'
//	A2 01 00 10 00      mov [0x00100001], al
//	B8 04 00 00 00      mov eax, 4              ; SYS_write
//	BB 01 00 00 00      mov ebx, 1              ; fd=stdout
//	B9 00 00 10 00      mov ecx, 0x00100000     ; buf
//	BA 02 00 00 00      mov edx, 2              ; len
//	CD 80               int 0x80                ; write(1, "OK", 2)
//	B8 01 00 00 00      mov eax, 1              ; SYS_exit
//	BB 00 00 00 00      mov ebx, 0
//	CD 80               int 0x80                ; exit(0)
func TestRunOnce_AbiMmapRequest(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const entry uint32 = 0x08048000
	code := []byte{
		0xB8, 0x03, 0x00, 0x10, 0x00,
		0xA3, 0x20, 0x00, 0xFE, 0x1F,
		0xB0, 0x4F,
		0xA2, 0x00, 0x00, 0x10, 0x00,
		0xB0, 0x4B,
		0xA2, 0x01, 0x00, 0x10, 0x00,
		0xB8, 0x04, 0x00, 0x00, 0x00,
		0xBB, 0x01, 0x00, 0x00, 0x00,
		0xB9, 0x00, 0x00, 0x10, 0x00,
		0xBA, 0x02, 0x00, 0x00, 0x00,
		0xCD, 0x80,
		0xB8, 0x01, 0x00, 0x00, 0x00,
		0xBB, 0x00, 0x00, 0x00, 0x00,
		0xCD, 0x80,
	}

	events, err := RunOnce(stub.Bytes, map[uint32][]byte{entry: code}, entry, testStackTop)
	if err != nil {
		t.Fatalf("RunOnce: %v", err)
	}
	want := []proto.Outbound{
		proto.Stdout{Bytes: []byte("OK")},
		proto.Exit{Code: 0},
	}
	if !reflect.DeepEqual(events, want) {
		t.Errorf("events:\n  got:  %#v\n  want: %#v", events, want)
	}
}

// TestRunOnce_AbiSetVideoMode_TrapMode pins the two-mode parity
// doctrine: the mov-only ABI dispatch must produce the same event
// stream under proto.ModeTrap as under proto.ModeHost. The runner
// owns the SIGSEGV interception regardless of which signal-dispatch
// mode it's running, so the guest sees identical behaviour either
// way — this is the mov-only ABI's equivalent of the sigaction
// parity tests.
func TestRunOnce_AbiSetVideoMode_TrapMode(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const entry uint32 = 0x08048000
	code := []byte{
		0xB0, 0x13,
		0xA2, 0x10, 0x00, 0xFE, 0x1F,
		0xB8, 0x01, 0x00, 0x00, 0x00,
		0xBB, 0x00, 0x00, 0x00, 0x00,
		0xCD, 0x80,
	}

	r, err := New(stub.Bytes)
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	defer r.Close()
	if err := r.WriteCode(entry, code); err != nil {
		t.Fatalf("WriteCode: %v", err)
	}
	ch := r.RunWithContextAndMode(proto.Context{
		Regs: proto.Regs{Eip: entry, Esp: testStackTop},
	}, proto.ModeTrap)
	var events []proto.Outbound
	for ev := range ch {
		events = append(events, ev)
	}
	want := []proto.Outbound{
		proto.VideoMode{Mode: 0x13},
		proto.Exit{Code: 0},
	}
	if !reflect.DeepEqual(events, want) {
		t.Errorf("events:\n  got:  %#v\n  want: %#v", events, want)
	}
}
