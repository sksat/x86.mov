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
#   gen_deck.py → deck.bin + deck_data.s   (raw RGBA slides + .incbin)
#   deck.c      → clang -emit-llvm → llvm-mov-llc → deck.s → deck.o
#   link: start.o + deck.o + deck_data.o + stubs_llvm.o, .fb13h @ 0xA0000
#
# Usage:  ./build-deck.sh [OUT_ELF] [N_SLIDES] [SRC_C]
#   OUT_ELF   default: kvm2026-kansai/deck.elf
#   N_SLIDES  default: 4
#   SRC_C     default: deck.c   (pass deck_bench.c for the bench build)
#
# Prereqs: llvm-mov-llc built (cd ../llvm-mov && make build LLVM_CONFIG=llvm-config
# on Arch, or per llvm-mov/CLAUDE.md), clang (clang-22), binutils
# `as --32` + `ld -m elf_i386`, python3.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

OUT="${1:-$HERE/kvm2026-kansai/deck.elf}"
N_SLIDES="${2:-4}"
SRC_C="${3:-$HERE/deck.c}"

CLANG="${CLANG:-clang-22}"
LLC="${LLC:-$ROOT/llvm-mov/build/bin/llvm-mov-llc}"

if [ ! -x "$LLC" ]; then
    echo "llvm-mov-llc not found at $LLC — build it first (see header)" >&2
    exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "[gen] $N_SLIDES slides"
python3 "$HERE/gen_deck.py" "$TMP" "$N_SLIDES"

echo "[llvm-mov] $(basename "$SRC_C")"
"$CLANG" -m32 -O2 -emit-llvm -S "$SRC_C" -o "$TMP/deck.ll"
"$LLC" -verify-machineinstrs "$TMP/deck.ll" -mtriple=mov-unknown-linux-gnu -o "$TMP/deck.s"

as --32 -mx86-used-note=no -o "$TMP/deck.o" "$TMP/deck.s"
as --32 -mx86-used-note=no -I "$TMP" -o "$TMP/deck_data.o" "$TMP/deck_data.s"
as --32 -mx86-used-note=no -o "$TMP/start.o" "$HERE/start.s"
as --32 -mx86-used-note=no -o "$TMP/stubs.o" "$HERE/stubs_llvm.s"

mkdir -p "$(dirname "$OUT")"
ld -m elf_i386 -static --hash-style=gnu \
    --section-start=.fb13h=0xA0000 --undefined=_fb13h_region \
    "$TMP/start.o" "$TMP/deck.o" "$TMP/deck_data.o" "$TMP/stubs.o" \
    -o "$OUT"
strip --strip-all "$OUT"
echo "  → $OUT ($(stat -c %s "$OUT") B)"
