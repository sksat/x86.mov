#!/usr/bin/env python3
# Rebase the committed example ELFs from their original 0x00001000
# link base to the Linux i386 convention 0x08048000 — same base
# turbo86's stub maps its RWX guest region at, so a Context handed off
# from movie86/wasm lands in writable territory on the turbo86 side.
# The `movie86::elf` loader follows whatever `p_vaddr` the ELF
# declares, so the same binary continues to run unchanged under movie86.
#
# Rewrites done per ELF:
#   - `e_entry` — old_base + offset → new_base + offset.
#   - each PT_LOAD `p_vaddr` / `p_paddr` — same shift.
#   - every `mov rXX, imm32` opcode (B8..BF) inside the LOAD segment
#     whose imm32 falls inside the original load range — bumped by the
#     same shift. For the bundled examples the data bytes ("Hello\n",
#     "Hi!\n", "1 ".."5 ") never collide with B8..BF, so the simple
#     scan-everything rule is safe; a future fixture whose data
#     overlaps would need a hand-coded offset table for that one
#     instead.
#
# Relative jumps/calls (E8/E9 rel32, EB rel8) and `int 0x80` need no
# rebase — they're position-independent across a uniform shift.

import struct
import sys
from pathlib import Path

OLD_BASE = 0x00001000
NEW_BASE = 0x08048000
SHIFT = NEW_BASE - OLD_BASE

# `mov r32, imm32` (B8 + reg index in the low 3 bits): EAX..EDI.
MOV_IMM32_OPCODES = set(range(0xB8, 0xC0))


def rebase_one(path: Path) -> None:
    data = bytearray(path.read_bytes())
    if data[:4] != b"\x7fELF" or data[4] != 1:
        raise SystemExit(f"{path}: not an ELF32")

    # ELF32-LE Ehdr offsets: e_entry=0x18, e_phoff=0x1C,
    # e_phentsize=0x2A, e_phnum=0x2C.
    (e_entry,) = struct.unpack_from("<I", data, 0x18)
    (e_phoff,) = struct.unpack_from("<I", data, 0x1C)
    (e_phentsize,) = struct.unpack_from("<H", data, 0x2A)
    (e_phnum,) = struct.unpack_from("<H", data, 0x2C)

    # Idempotency: if `e_entry` already sits at or above NEW_BASE,
    # the ELF was rebased before — leave it alone. Re-running the
    # script on a checked-in (already-rebased) fixture must be a
    # no-op so `make rebase-examples` is safe to call repeatedly.
    if e_entry >= NEW_BASE:
        print(f"skip {path.name}: entry 0x{e_entry:x} already at/above new base")
        return
    if e_entry < OLD_BASE:
        raise SystemExit(f"{path}: e_entry 0x{e_entry:x} below OLD_BASE")

    struct.pack_into("<I", data, 0x18, e_entry + SHIFT)

    load_segments: list[tuple[int, int, int]] = []  # (file_off, filesz, orig_vaddr)
    for i in range(e_phnum):
        ph = e_phoff + i * e_phentsize
        (p_type,) = struct.unpack_from("<I", data, ph + 0)
        if p_type != 1:  # PT_LOAD
            continue
        (p_offset,) = struct.unpack_from("<I", data, ph + 0x04)
        (p_vaddr,) = struct.unpack_from("<I", data, ph + 0x08)
        (p_paddr,) = struct.unpack_from("<I", data, ph + 0x0C)
        (p_filesz,) = struct.unpack_from("<I", data, ph + 0x10)
        struct.pack_into("<I", data, ph + 0x08, p_vaddr + SHIFT)
        struct.pack_into("<I", data, ph + 0x0C, p_paddr + SHIFT)
        load_segments.append((p_offset, p_filesz, p_vaddr))

    for p_offset, p_filesz, orig_vaddr in load_segments:
        orig_lo = orig_vaddr
        orig_hi = orig_vaddr + p_filesz
        i = 0
        while i + 5 <= p_filesz:
            if data[p_offset + i] in MOV_IMM32_OPCODES:
                imm_off = p_offset + i + 1
                (imm,) = struct.unpack_from("<I", data, imm_off)
                if orig_lo <= imm < orig_hi:
                    struct.pack_into("<I", data, imm_off, imm + SHIFT)
                    i += 5
                    continue
            i += 1

    path.write_bytes(data)
    print(f"rebased {path.name}: entry 0x{e_entry:x} → 0x{e_entry + SHIFT:x}")


def main() -> None:
    here = Path(__file__).parent
    elfs = [Path(p) for p in (sys.argv[1:] or sorted(str(p) for p in here.glob("*.elf")))]
    for p in elfs:
        rebase_one(p)


if __name__ == "__main__":
    main()
