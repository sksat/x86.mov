package stub

import (
	"bytes"
	"encoding/binary"
	"testing"
)

func TestEmbeddedStubIsELF32(t *testing.T) {
	if !bytes.HasPrefix(Bytes, []byte{0x7F, 'E', 'L', 'F'}) {
		t.Fatalf("embedded stub does not start with ELF magic; got: % x ...", Bytes[:8])
	}
	// e_ident[EI_CLASS] at offset 4: 1 == ELFCLASS32.
	if got := Bytes[4]; got != 1 {
		t.Errorf("expected ELFCLASS32 (1) at e_ident[4], got %d", got)
	}
	// e_machine at offset 18..19 (little-endian): 3 == EM_386.
	if got := binary.LittleEndian.Uint16(Bytes[18:20]); got != 3 {
		t.Errorf("expected EM_386 (3) at e_machine, got %d", got)
	}
}

func TestEmbeddedStubNonEmpty(t *testing.T) {
	if len(Bytes) == 0 {
		t.Fatal("embedded stub is empty; did `make` run in stub/?")
	}
}
