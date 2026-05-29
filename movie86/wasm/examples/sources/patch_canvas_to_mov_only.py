#!/usr/bin/env python3
"""Patch canvas_*.elf fixtures to use the mov-only ABI in place of int 0x10 / int 0x80.

We don't have the original generator that produced canvas_smile,
canvas_modes, canvas_bars (long sequences of `mov [imm32], eax` pixel
writes), so this script is the closest thing to a source: it
transforms the legacy committed binaries into byte-equivalent
mov-only versions, preserving every pixel write's target address by
keeping the patched-in mov sequences the same byte-length as the
originals they replace.
"""

# Patterns transformed:
#
#
# Two patterns are matched:
#
#   set_video_mode (7 bytes, in / out):
#       B8 NN 00 00 00 CD 10      mov eax, NN ; int 0x10
#     →
#       B0 NN A2 10 00 FE 1F      mov al, NN ; mov [0x1FFE0010], al
#
#   exit (12 bytes, in / out):
#       BB NN NN NN NN B8 01 00 00 00 CD 80      mov ebx, status ; mov eax, 1 ; int 0x80
#     →
#       B8 NN NN NN NN A3 FE 00 FE 1F 90 90      mov eax, status ; mov [0x1FFE00FE], eax ; nop ; nop
#
# Both replacements keep the surrounding pixel-write `mov [imm32], eax`
# instructions at exactly the same file offsets, so the binary's
# semantics are preserved end-to-end.

import argparse
import struct
import sys
from pathlib import Path


def find_exec_segments(buf):
    """Return list of (file_offset, file_size) for PT_LOAD segments with PF_X.

    Parses just enough of the ELF32 header / program-header table to find
    executable segments. Falls back to a no-op (empty list) if the file
    doesn't look like a valid i386 ELF.
    """
    if len(buf) < 0x34 or buf[:4] != b"\x7fELF" or buf[4] != 1 or buf[5] != 1:
        return []
    e_phoff = struct.unpack_from("<I", buf, 0x1C)[0]
    e_phentsize = struct.unpack_from("<H", buf, 0x2A)[0]
    e_phnum = struct.unpack_from("<H", buf, 0x2C)[0]
    out = []
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        if off + 32 > len(buf):
            break
        p_type, p_offset = struct.unpack_from("<II", buf, off)
        p_filesz = struct.unpack_from("<I", buf, off + 0x10)[0]
        p_flags = struct.unpack_from("<I", buf, off + 0x18)[0]
        if p_type == 1 and (p_flags & 1):  # PT_LOAD, PF_X
            out.append((p_offset, p_filesz))
    return out


def patch_segment(seg_bytes):
    """Return (new_bytes, set_count, exit_count)."""
    new = bytearray(seg_bytes)
    set_count = 0
    # set_video_mode: B8 NN 00 00 00 CD 10  →  B0 NN A2 10 00 FE 1F
    i = 0
    while i + 7 <= len(new):
        if (
            new[i] == 0xB8
            and new[i + 2] == 0x00
            and new[i + 3] == 0x00
            and new[i + 4] == 0x00
            and new[i + 5] == 0xCD
            and new[i + 6] == 0x10
        ):
            mode = new[i + 1]
            new[i : i + 7] = bytes([0xB0, mode, 0xA2, 0x10, 0x00, 0xFE, 0x1F])
            set_count += 1
            i += 7
        else:
            i += 1

    exit_count = 0
    # exit: BB ?? ?? ?? ?? B8 01 00 00 00 CD 80  →
    #       B8 ?? ?? ?? ?? A3 FE 00 FE 1F 90 90
    i = 0
    while i + 12 <= len(new):
        if (
            new[i] == 0xBB
            and new[i + 5] == 0xB8
            and new[i + 6] == 0x01
            and new[i + 7] == 0x00
            and new[i + 8] == 0x00
            and new[i + 9] == 0x00
            and new[i + 10] == 0xCD
            and new[i + 11] == 0x80
        ):
            status = bytes(new[i + 1 : i + 5])
            new[i : i + 12] = (
                bytes([0xB8]) + status + bytes([0xA3, 0xFE, 0x00, 0xFE, 0x1F, 0x90, 0x90])
            )
            exit_count += 1
            i += 12
        else:
            i += 1

    return bytes(new), set_count, exit_count


def patch_elf(in_path, out_path):
    data = bytearray(in_path.read_bytes())
    segs = find_exec_segments(bytes(data))
    if not segs:
        print(f"  {in_path.name}: no executable PT_LOAD segments found", file=sys.stderr)
        return False
    total_set, total_exit = 0, 0
    for seg_off, seg_size in segs:
        chunk = bytes(data[seg_off : seg_off + seg_size])
        patched, sc, ec = patch_segment(chunk)
        data[seg_off : seg_off + seg_size] = patched
        total_set += sc
        total_exit += ec
    out_path.write_bytes(bytes(data))
    print(f"  {in_path.name}: set_video_mode={total_set} exit={total_exit}")
    return True


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("elfs", nargs="+", type=Path, help="ELF files to patch in place")
    args = ap.parse_args()
    for p in args.elfs:
        patch_elf(p, p)


if __name__ == "__main__":
    main()
