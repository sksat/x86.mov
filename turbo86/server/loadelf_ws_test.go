//go:build linux

package server_test

import (
	"context"
	"debug/elf"
	"encoding/binary"
	"net/http/httptest"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"

	"github.com/sksat/x86.mov/turbo86/proto"
	"github.com/sksat/x86.mov/turbo86/server"
)

// buildExitElf32 hand-assembles a minimal, valid ELF32 (i386) executable
// with a single PT_LOAD segment at `entry` whose bytes are `code` (a
// mov-only program). It mirrors the runner package's (unexported,
// test-only) buildElf32 helper closely enough to exercise the server's
// LoadElf inbound path end-to-end without reaching across the package
// boundary. Layout: [Elf32_Ehdr][one Elf32_Phdr][segment bytes].
func buildExitElf32(entry uint32, code []byte) []byte {
	const (
		ehSize = 52 // sizeof(Elf32_Ehdr)
		phSize = 32 // sizeof(Elf32_Phdr)
	)
	phoff := uint32(ehSize)
	dataOff := phoff + phSize
	total := dataOff + uint32(len(code))
	img := make([]byte, total)

	// --- ELF header (Elf32_Ehdr) ---
	copy(img[0:], []byte{0x7F, 'E', 'L', 'F'})
	img[elf.EI_CLASS] = byte(elf.ELFCLASS32)
	img[elf.EI_DATA] = byte(elf.ELFDATA2LSB)
	img[elf.EI_VERSION] = byte(elf.EV_CURRENT)
	img[elf.EI_OSABI] = byte(elf.ELFOSABI_NONE)
	binary.LittleEndian.PutUint16(img[16:], uint16(elf.ET_EXEC))    // e_type
	binary.LittleEndian.PutUint16(img[18:], uint16(elf.EM_386))     // e_machine
	binary.LittleEndian.PutUint32(img[20:], uint32(elf.EV_CURRENT)) // e_version
	binary.LittleEndian.PutUint32(img[24:], entry)                  // e_entry
	binary.LittleEndian.PutUint32(img[28:], phoff)                  // e_phoff
	binary.LittleEndian.PutUint32(img[32:], 0)                      // e_shoff
	binary.LittleEndian.PutUint32(img[36:], 0)                      // e_flags
	binary.LittleEndian.PutUint16(img[40:], ehSize)                 // e_ehsize
	binary.LittleEndian.PutUint16(img[42:], phSize)                 // e_phentsize
	binary.LittleEndian.PutUint16(img[44:], 1)                      // e_phnum
	binary.LittleEndian.PutUint16(img[46:], 0)                      // e_shentsize
	binary.LittleEndian.PutUint16(img[48:], 0)                      // e_shnum
	binary.LittleEndian.PutUint16(img[50:], 0)                      // e_shstrndx

	// --- Program header (Elf32_Phdr) ---
	binary.LittleEndian.PutUint32(img[phoff+0:], uint32(elf.PT_LOAD))                 // p_type
	binary.LittleEndian.PutUint32(img[phoff+4:], dataOff)                             // p_offset
	binary.LittleEndian.PutUint32(img[phoff+8:], entry)                               // p_vaddr
	binary.LittleEndian.PutUint32(img[phoff+12:], entry)                              // p_paddr
	binary.LittleEndian.PutUint32(img[phoff+16:], uint32(len(code)))                  // p_filesz
	binary.LittleEndian.PutUint32(img[phoff+20:], uint32(len(code)))                  // p_memsz
	binary.LittleEndian.PutUint32(img[phoff+24:], uint32(elf.PF_R|elf.PF_W|elf.PF_X)) // p_flags
	binary.LittleEndian.PutUint32(img[phoff+28:], 0x1000)                             // p_align

	copy(img[dataOff:], code)
	return img
}

// TestE2E_LoadElf_OverWebSocket drives the LoadElf startup shape
// end-to-end over the in-process WebSocket server: a proto.LoadElf
// inbound carrying a minimal ELF32 whose single PT_LOAD at 0x08048000 is
// a mov-only exit(42) program. The server must parse the ELF, stage +
// apply the segment, run from e_entry, and stream back a terminal
// Exit{42}. Mirrors the existing LoadContext WS cases for the third
// startup path.
func TestE2E_LoadElf_OverWebSocket(t *testing.T) {
	srv := httptest.NewServer(server.Handler(nil))
	defer srv.Close()

	wsURL := "ws" + strings.TrimPrefix(srv.URL, "http")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	ws, _, err := websocket.Dial(ctx, wsURL, nil)
	if err != nil {
		t.Fatalf("Dial: %v", err)
	}
	defer ws.CloseNow()

	const entry uint32 = 0x08048000
	// Guest:
	//   B8 2A 00 00 00      mov eax, 42            ; exit code
	//   A3 FE 00 FE 1F      mov [0x1FFE00FE], eax  ; ABI exit(42)
	code := []byte{
		0xB8, 0x2A, 0x00, 0x00, 0x00,
		0xA3, 0xFE, 0x00, 0xFE, 0x1F,
	}
	img := buildExitElf32(entry, code)

	sendInbound(t, ctx, ws, proto.LoadElf{
		Elf:  img,
		Mode: proto.ModeHost,
	})

	got := readAllEvents(t, ctx, ws)
	want := []proto.Outbound{proto.Exit{Code: 42}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("events:\n  got:  %#v\n  want: %#v", got, want)
	}
}
