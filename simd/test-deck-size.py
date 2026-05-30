#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pymupdf"]
# ///
"""TDD guard: the SIMD86 deck must fit turbo86's guest code/data region.

The "acceleration boost" hands the live movie86 session over to a local
turbo86 process, which restores the guest snapshot into the stub's
static RWX region: **16 MiB at 0x08048000** (see `turbo86/stub/_stub.s`
lines 30-31 and `runner.go` `guestRegions = {0x08048000, 0x01000000}`).
The deck's slide images are baked into the ELF's `.rodata`
(`slides_data[]`, see gen_deck.py) contiguously after `.text`, so the
whole slide blob has to fit inside that 16 MiB — otherwise the handover
write runs past 0x09048000 and the boost breaks. Framebuffer regions
live below the stub region and are mmap'd dynamically, so they don't
count against this budget; only the baked-in slide blob does.

This pins the *resolution policy*: rendering the committed deck.pdf at
pdf_to_deck.py's default resolution must produce a `slides_data` blob
within budget. At 1280x720 (the old default) a 46-slide deck is ~162
MiB and fails; at 320x180 it is ~10 MiB and passes.

Run:  uv run simd/test-deck-size.py   (or ./test-deck-size.py from simd/)
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import pdf_to_deck  # noqa: E402  module import is cheap (fitz import is lazy)
import gen_deck     # noqa: E402  ditto (Pillow import is lazy)

DECK_PDF = os.path.join(HERE, "kvm2026-kansai", "deck.pdf")

# turbo86 stub guest code/data region (turbo86/stub/_stub.s:30-31,
# runner.go guestRegions): 16 MiB at 0x08048000. slides_data shares it
# with .text + the slide table + ELF headers, so reserve headroom.
GUEST_REGION = 0x0100_0000             # 16 MiB
CODE_HEADROOM = 1 * 1024 * 1024        # room for code / headers / non-FB data
BUDGET = GUEST_REGION - CODE_HEADROOM  # 15 MiB for the slide blob itself


def slides_data_bytes(pdf_path):
    """Sum w*h*4 over the deck, mirroring pdf_to_deck's per-slide
    resolution choice — the exact size gen_deck bakes into slides_data[]."""
    import fitz  # pymupdf, from the PEP 723 dependency
    n = fitz.open(pdf_path).page_count
    fw, fh = pdf_to_deck.parse_res(pdf_to_deck.DEFAULT_FIRST_RES)
    rw, rh = pdf_to_deck.parse_res(pdf_to_deck.DEFAULT_RES)
    total = 0
    for i in range(n):
        w, h = (fw, fh) if i == 0 else (rw, rh)
        total += w * h * 4
    return n, total


def main():
    failed = 0

    # 1) The committed deck at the default resolution fits the boost budget.
    try:
        n, size = slides_data_bytes(DECK_PDF)
        assert size <= BUDGET, (
            f"deck slides_data {size / 1024 / 1024:.1f} MiB ({n} slides at "
            f"default {pdf_to_deck.DEFAULT_RES}) exceeds turbo86 budget "
            f"{BUDGET / 1024 / 1024:.0f} MiB — boost handover would overrun "
            f"the 16 MiB stub region at 0x08048000")
        print(f"ok  deck fits: {size / 1024 / 1024:.1f} MiB / "
              f"{BUDGET / 1024 / 1024:.0f} MiB ({n} slides @ "
              f"{pdf_to_deck.DEFAULT_RES})")
    except Exception as e:
        print(f"FAIL deck size: {e}")
        failed = 1

    # 2) The default resolution is a real 16:9 framebuffer mode known to
    #    gen_deck (MODES). Keeps the compromise honest: low-res but not
    #    letterboxed.
    try:
        w, h = pdf_to_deck.parse_res(pdf_to_deck.DEFAULT_RES)
        assert (w, h) in gen_deck.MODES, \
            f"default {w}x{h} is not a gen_deck framebuffer mode"
        assert abs(w / h - 16 / 9) < 1e-6, f"default {w}x{h} is not 16:9"
        mode, addr = gen_deck.MODES[(w, h)]
        print(f"ok  default {w}x{h} -> mode {mode:#x} @ {addr:#x}, 16:9")
    except Exception as e:
        print(f"FAIL default mode: {e}")
        failed = 1

    sys.exit(failed)


if __name__ == "__main__":
    main()
