//go:build linux

package runner

import (
	"bytes"
	"compress/gzip"
	"reflect"
	"runtime"
	"testing"

	"github.com/sksat/x86.mov/turbo86/proto"
	"github.com/sksat/x86.mov/turbo86/stub"
)

// gzipBytes gzip-compresses b, matching what the browser's
// CompressionStream('gzip') produces for the boost payload.
func gzipBytes(t *testing.T, b []byte) []byte {
	t.Helper()
	var buf bytes.Buffer
	w := gzip.NewWriter(&buf)
	if _, err := w.Write(b); err != nil {
		t.Fatalf("gzip write: %v", err)
	}
	if err := w.Close(); err != nil {
		t.Fatalf("gzip close: %v", err)
	}
	return buf.Bytes()
}

// TestLoadElf_GzipCompressedImage feeds LoadElf a gzip-compressed ELF
// image instead of a raw one. This is the real boost wire shape: the
// SIMD86 deck.elf is ~160 MiB raw, so the browser compresses it with the
// native CompressionStream before sending proto.LoadElf — a few MB on the
// wire instead of a ~213 MiB base64 blob. turbo86 must detect the gzip
// magic (1F 8B), inflate, then load+run the inner ELF exactly as if it
// had arrived raw. The inner program is the same exit(42) fixture as
// TestLoadElf_ExitFromArena, so a clean Exit{42} proves the gzip path
// only adds transparent decompression.
func TestLoadElf_GzipCompressedImage(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const entry uint32 = 0x08048000

	//   B8 2A 00 00 00      mov eax, 42            ; exit code
	//   A3 FE 00 FE 1F      mov [0x1FFE00FE], eax  ; ABI exit(42)
	code := []byte{
		0xB8, 0x2A, 0x00, 0x00, 0x00,
		0xA3, 0xFE, 0x00, 0xFE, 0x1F,
	}
	raw := buildElf32(entry, []elfSeg{
		{vaddr: entry, data: code, memsz: uint32(len(code))},
	})
	img := gzipBytes(t, raw)
	if img[0] != 0x1f || img[1] != 0x8b {
		t.Fatalf("fixture not gzip: magic %02x %02x", img[0], img[1])
	}

	r, err := New(stub.Bytes)
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	defer r.Close()

	if err := r.LoadElf(img, proto.ModeHost, 0, nil); err != nil {
		t.Fatalf("LoadElf (gzip): %v", err)
	}
	var events []proto.Outbound
	for ev := range r.Run(entry, testStackTop) {
		events = append(events, ev)
	}
	want := []proto.Outbound{proto.Exit{Code: 42}}
	if !reflect.DeepEqual(events, want) {
		t.Errorf("events:\n  got:  %#v\n  want: %#v", events, want)
	}
}
