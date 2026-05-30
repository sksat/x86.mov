//go:build linux

package runner

import (
	"encoding/binary"
	"reflect"
	"runtime"
	"testing"

	"debug/elf"

	"github.com/sksat/x86.mov/turbo86/proto"
	"github.com/sksat/x86.mov/turbo86/stub"
)

// buildElf32 hand-assembles a minimal, valid ELF32 (i386) executable
// image: a 52-byte ELF header, one program-header-table entry per
// PT_LOAD segment, then each segment's file bytes laid out at its
// p_offset. We write the headers by hand (rather than leaning on a
// linker) so the test fixture is self-contained and the LoadElf parser
// is exercised against bytes we fully control — including the exact
// e_entry / p_vaddr / p_filesz / p_memsz fields the loader reads back.
//
// `entry` is e_entry. Each segment is (vaddr, data, memsz): `data` is the
// file image (becomes p_filesz bytes), `memsz` is the in-memory size
// (>= len(data); the trailing memsz-filesz is BSS the loader zero-fills
// via anonymous mmap). Segments are emitted in the order given.
func buildElf32(entry uint32, segs []elfSeg) []byte {
	const (
		ehSize = 52 // sizeof(Elf32_Ehdr)
		phSize = 32 // sizeof(Elf32_Phdr)
	)
	phoff := uint32(ehSize)
	phnum := len(segs)
	// File layout: [ehdr][phdrs...][seg0 data][seg1 data]...
	dataOff := phoff + uint32(phnum*phSize)

	// Compute each segment's file offset (where its bytes live in the image).
	offsets := make([]uint32, phnum)
	cur := dataOff
	for i, s := range segs {
		offsets[i] = cur
		cur += uint32(len(s.data))
	}
	total := cur

	img := make([]byte, total)

	// --- ELF header (Elf32_Ehdr) ---
	copy(img[0:], []byte{0x7F, 'E', 'L', 'F'}) // e_ident magic
	img[elf.EI_CLASS] = byte(elf.ELFCLASS32)
	img[elf.EI_DATA] = byte(elf.ELFDATA2LSB)
	img[elf.EI_VERSION] = byte(elf.EV_CURRENT)
	img[elf.EI_OSABI] = byte(elf.ELFOSABI_NONE)
	// e_ident[8:16] padding stays zero.
	binary.LittleEndian.PutUint16(img[16:], uint16(elf.ET_EXEC))    // e_type
	binary.LittleEndian.PutUint16(img[18:], uint16(elf.EM_386))     // e_machine
	binary.LittleEndian.PutUint32(img[20:], uint32(elf.EV_CURRENT)) // e_version
	binary.LittleEndian.PutUint32(img[24:], entry)                  // e_entry
	binary.LittleEndian.PutUint32(img[28:], phoff)                  // e_phoff
	binary.LittleEndian.PutUint32(img[32:], 0)                      // e_shoff
	binary.LittleEndian.PutUint32(img[36:], 0)                      // e_flags
	binary.LittleEndian.PutUint16(img[40:], ehSize)                 // e_ehsize
	binary.LittleEndian.PutUint16(img[42:], phSize)                 // e_phentsize
	binary.LittleEndian.PutUint16(img[44:], uint16(phnum))          // e_phnum
	binary.LittleEndian.PutUint16(img[46:], 0)                      // e_shentsize
	binary.LittleEndian.PutUint16(img[48:], 0)                      // e_shnum
	binary.LittleEndian.PutUint16(img[50:], 0)                      // e_shstrndx

	// --- Program headers (Elf32_Phdr) ---
	for i, s := range segs {
		base := phoff + uint32(i*phSize)
		binary.LittleEndian.PutUint32(img[base+0:], uint32(elf.PT_LOAD))                 // p_type
		binary.LittleEndian.PutUint32(img[base+4:], offsets[i])                          // p_offset
		binary.LittleEndian.PutUint32(img[base+8:], s.vaddr)                             // p_vaddr
		binary.LittleEndian.PutUint32(img[base+12:], s.vaddr)                            // p_paddr
		binary.LittleEndian.PutUint32(img[base+16:], uint32(len(s.data)))                // p_filesz
		binary.LittleEndian.PutUint32(img[base+20:], s.memsz)                            // p_memsz
		binary.LittleEndian.PutUint32(img[base+24:], uint32(elf.PF_R|elf.PF_W|elf.PF_X)) // p_flags
		binary.LittleEndian.PutUint32(img[base+28:], 0x1000)                             // p_align
	}

	// --- Segment data ---
	for i, s := range segs {
		copy(img[offsets[i]:], s.data)
	}
	return img
}

type elfSeg struct {
	vaddr uint32
	data  []byte
	memsz uint32
}

// TestLoadElf_ExitFromArena loads a complete ELF32 with one PT_LOAD
// segment that lives entirely inside the stub's static 16 MiB arena
// ([0x08048000, 0x09048000)). The segment's bytes are a hand-assembled
// mov-only program that exits with code 42 via the mov-only ABI exit
// slot (0x0FE). e_entry points at the start of the segment. After
// LoadElf maps the segment and sets EIP=e_entry/ESP=stackTop, Run()
// must drive the guest to emit exactly Exit{42} — proving the loader's
// header parse, in-arena write, and entry/stack setup all line up.
func TestLoadElf_ExitFromArena(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const entry uint32 = 0x08048000

	// Guest:
	//   B8 2A 00 00 00      mov eax, 42            ; exit code
	//   A3 FE 00 FE 1F      mov [0x1FFE00FE], eax  ; ABI exit(42)
	code := []byte{
		0xB8, 0x2A, 0x00, 0x00, 0x00,
		0xA3, 0xFE, 0x00, 0xFE, 0x1F,
	}
	img := buildElf32(entry, []elfSeg{
		{vaddr: entry, data: code, memsz: uint32(len(code))},
	})

	r, err := New(stub.Bytes)
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	defer r.Close()

	if err := r.LoadElf(img, proto.ModeHost, 0, nil); err != nil {
		t.Fatalf("LoadElf: %v", err)
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

// TestLoadElf_SegmentBeyondArena loads an ELF32 with TWO PT_LOAD
// segments: code inside the arena that reads a byte from a high address
// (0x10000000, well outside the static 16 MiB arena) and uses it as the
// exit code, plus a one-page data segment at that high vaddr whose first
// byte is 42. For the read to succeed the loader must mmap the
// out-of-arena segment into the guest (anon RWX, MAP_FIXED) and write
// its file bytes there before execution. A successful Exit{42} proves
// the loader's out-of-arena mmap + write path end-to-end.
func TestLoadElf_SegmentBeyondArena(t *testing.T) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	const entry uint32 = 0x08048000
	const dataVaddr uint32 = 0x10000000

	// Guest:
	//   A0 00 00 00 10      mov al, [0x10000000]   ; al = byte at data seg
	//   A2 FE 00 FE 1F      mov [0x1FFE00FE], al    ; ABI exit(al)
	code := []byte{
		0xA0, 0x00, 0x00, 0x00, 0x10,
		0xA2, 0xFE, 0x00, 0xFE, 0x1F,
	}
	// One-page data segment; first byte is the exit code, rest zero.
	data := make([]byte, pageSize)
	data[0] = 42

	img := buildElf32(entry, []elfSeg{
		{vaddr: entry, data: code, memsz: uint32(len(code))},
		{vaddr: dataVaddr, data: data, memsz: uint32(len(data))},
	})

	r, err := New(stub.Bytes)
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	defer r.Close()

	if err := r.LoadElf(img, proto.ModeHost, 0, nil); err != nil {
		t.Fatalf("LoadElf: %v", err)
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
