#!/usr/bin/env bash
# Build a SIMD86 deck ELF from deck.c + a generated slide blob, via the
# llvm-mov pipeline (clang -emit-llvm → llvm-mov-llc → mov-target asm).
#
# Why llvm-mov rather than movfuscator: llvm-mov emits ordinary jmp/call
# control flow, so the deck runs *natively* on turbo86 (full speed, the
# point of the handover for live presentation). movfuscator's SIGILL
# master_loop dispatch doesn't run to completion on turbo86 yet — see
# the GitHub issue on running movfuscator output natively on turbo86.
#
#   deck.pdf → pdf_to_deck.py → slideNN.png + deck.toml  (if no deck.toml)
#   deck.toml → gen_deck.py   → deck.bin + deck_data.s   (memory image)
#   deck.c                → clang -emit-llvm → llvm-mov-llc → deck.s → deck.o
#   link: start.o + deck.o + deck_data.o + stubs_llvm.o, FB regions pinned
#
# Deck source: a deck is authored as either a deck.toml (+ image files) or
# a deck.pdf. When DECK_TOML doesn't exist but a deck.pdf sits next to it,
# this script renders the PDF into a scratch dir via pdf_to_deck.py and
# builds from that — so CI only needs to commit the PDF, not the (large)
# rendered PNGs or the deck.elf.
#
# Usage:  ./build-deck.sh [OUT_ELF] [DECK_TOML] [SRC_C]
#   OUT_ELF    default: kvm2026-kansai/deck.elf
#   DECK_TOML  default: kvm2026-kansai/deck.toml (or generated from
#              kvm2026-kansai/deck.pdf if absent)
#   SRC_C      default: deck.c   (pass deck_bench.c for the bench build)
#
# FB sections: each video mode the deck uses needs its .fbNNN section
# (stubs_llvm.s) pinned here with --section-start. Keep this list in sync
# with stubs_llvm.s / gen_deck.py MODES.
#
# Prereqs: llvm-mov-llc built (cd ../llvm-mov && make build LLVM_CONFIG=llvm-config
# on Arch, or per llvm-mov/CLAUDE.md), clang (clang-22), binutils
# `as --32` + `ld -m elf_i386`, uv (the PEP 723 header in gen_deck.py
# pins Python + Pillow, so `uv run` needs no manual venv).

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

OUT="${1:-$HERE/kvm2026-kansai/deck.elf}"
DECK_TOML="${2:-$HERE/kvm2026-kansai/deck.toml}"
SRC_C="${3:-$HERE/deck.c}"

CLANG="${CLANG:-clang-22}"
LLC="${LLC:-$ROOT/llvm-mov/build/bin/llvm-mov-llc}"

if [ ! -x "$LLC" ]; then
    echo "llvm-mov-llc not found at $LLC — build it first (see header)" >&2
    exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Resolve the deck spec. If there's no deck.toml but a deck.pdf sits in
# the same dir, render the PDF into a scratch dir (slideNN.png + deck.toml)
# and build from there. images in deck.toml are relative to its own dir,
# so gen_deck below runs against whichever dir won.
DECK_DIR="$(dirname "$DECK_TOML")"
if [ ! -f "$DECK_TOML" ] && [ -f "$DECK_DIR/deck.pdf" ]; then
    echo "[pdf] $(basename "$DECK_DIR/deck.pdf") → deck.toml + slides"
    uv run "$HERE/pdf_to_deck.py" "$DECK_DIR/deck.pdf" -o "$TMP/deck"
    DECK_TOML="$TMP/deck/deck.toml"
fi

echo "[gen] $(basename "$DECK_TOML")"
uv run "$HERE/gen_deck.py" "$DECK_TOML" -o "$TMP"

echo "[llvm-mov] $(basename "$SRC_C")"
# -O2: this deck legalizes to ~99.5% mov at every opt level (the only
# non-mov left is jmp), and -O2 is both the highest (99.52%) and the
# fastest — it unrolls the blit loop, so the slide draw is the fewest
# dynamic mov on movie86. (Build prints the mov rate below.)
"$CLANG" -m32 -O2 -emit-llvm -S "$SRC_C" -o "$TMP/deck.ll"
"$LLC" -verify-machineinstrs "$TMP/deck.ll" -mtriple=mov-unknown-linux-gnu -o "$TMP/deck.s"

as --32 -mx86-used-note=no -o "$TMP/deck.o" "$TMP/deck.s"
as --32 -mx86-used-note=no -I "$TMP" -o "$TMP/deck_data.o" "$TMP/deck_data.s"
as --32 -mx86-used-note=no -o "$TMP/start.o" "$HERE/start.s"
as --32 -mx86-used-note=no -o "$TMP/stubs.o" "$HERE/stubs_llvm.s"

mkdir -p "$(dirname "$OUT")"
ld -m elf_i386 -static --hash-style=gnu \
    --section-start=.fb70=0x800000 --undefined=_fb70_region \
    --section-start=.fb72=0xC00000 --undefined=_fb72_region \
    "$TMP/start.o" "$TMP/deck.o" "$TMP/deck_data.o" "$TMP/stubs.o" \
    -o "$OUT"
strip --strip-all "$OUT"
echo "  → $OUT ($(stat -c %s "$OUT") B)"

# Report the slide system's mov rate — the fraction of .text instructions
# that are mov (the "Single Instruction" metric). llvm-mov + the stubs
# leave a few jmp/call/ret behind; the deck body itself is essentially
# all mov. Printed every build so regressions in mov-ness are visible.
total=$(objdump -d "$OUT" | awk -F'\t' 'NF>=3 {n++} END {print n+0}')
movs=$(objdump -d "$OUT" | awk -F'\t' 'NF>=3 {split($3, a, " "); if (a[1] ~ /^mov/) n++} END {print n+0}')
if [ "$total" -gt 0 ]; then
    printf "  mov rate: %d / %d = %.2f%% mov\n" "$movs" "$total" \
        "$(awk "BEGIN { print $movs * 100 / $total }")"
fi
