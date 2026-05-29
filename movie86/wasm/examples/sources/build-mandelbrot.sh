#!/usr/bin/env bash
# Build three flavours of `canvas_mandelbrot*.elf` from two C sources.
#
#   mandelbrot_coarse.c → (movfuscator pipeline) → canvas_mandelbrot_mov.elf
#   mandelbrot_coarse.c → (clang -O2 → llvm-mov-llc) → canvas_mandelbrot.elf
#   mandelbrot_hires.c  → (clang -O2 → llvm-mov-llc) → canvas_mandelbrot_hires.elf
#
# The "coarse" variant computes a small 80×50 grid and blits each cell
# as a 4×4 block of mode-13h pixels; "hires" computes the full 320×200
# at MAX_ITER=24 for a sharper boundary. movfuscator-coarse exists as
# a slow side-by-side comparison; movfuscator-hires would take many
# hours so we skip it.
#
# All three flavours are statically linked, ship a `.fb13h` BSS region
# at guest address 0xA0000 (mode 13h), and rely on a small
# `set_video_mode` stub wrapping `int 0x10` (AH=0, AL=mode).
#
# **Don't `--strip-all` the movfuscator binary.** movie86 relies on the
# ELF symbol table to auto-wire `dispatch` (SIGSEGV) and `master_loop`
# (SIGILL) — strip-all kills the symtab and the runtime's NULL-deref
# dispatch trick stops working (manifests as `Unmapped(0)` mid-run).
# `--strip-debug` is fine (and almost free here — movfuscator output
# has no debug info to remove).
#
# Prereqs:
#   - movfuscator-wasm/vendor (`make -C movfuscator-wasm setup build-native`)
#   - llvm-mov/build (`make -C llvm-mov build`)
#   - binutils with `as --32` + `ld -m elf_i386`
#   - clang-22 (host LLVM matching llvm-mov-llc's version)

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"

EX="$HERE/.."
B="$ROOT/movfuscator-wasm/vendor/movfuscator/build"
SF="$ROOT/movfuscator-wasm/vendor/movfuscator/movfuscator/lib"
LLC="$ROOT/llvm-mov/build/bin/llvm-mov-llc"
CLANG="${CLANG:-clang-22}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

as --32 -mx86-used-note=no -o "$TMP/stubs_mov.o" "$HERE/stubs_movfuscator.s"
as --32 -mx86-used-note=no -o "$TMP/stubs_llvm.o" "$HERE/stubs_llvm.s"
as --32 -mx86-used-note=no -o "$TMP/_start_llvm.o" "$HERE/_start_llvm.s"

# ============================================================
# movfuscator pipeline (coarse only — hires would take hours)
# ============================================================
echo "[movfuscator] mandelbrot_coarse.c"
"$ROOT/movfuscator-wasm/scripts/preprocess.sh" "$HERE/mandelbrot_coarse.c" "$TMP/coarse.i" >/dev/null
"$B/rcc" -target=x86/mov "$TMP/coarse.i" "$TMP/coarse_mov.s"
as --32 -mx86-used-note=no -o "$TMP/coarse_mov.o" "$TMP/coarse_mov.s" 2>/dev/null
ld -m elf_i386 -static --hash-style=gnu \
    --section-start=.fb13h=0xA0000 --undefined=_fb13h_region \
    "$B/crt0.o" "$TMP/coarse_mov.o" "$B/crtf.o" "$B/crtd.o" "$SF/softfloat32.o" "$TMP/stubs_mov.o" \
    -o "$EX/canvas_mandelbrot_mov.elf"
# Keep symtab intact — see header note. --strip-debug is nearly a no-op here.
strip --strip-debug "$EX/canvas_mandelbrot_mov.elf"
echo "  → $(stat -c %s "$EX/canvas_mandelbrot_mov.elf") B"

# ============================================================
# llvm-mov pipeline — build both coarse and hires
# ============================================================
build_llvm() {
    local src="$1" out="$2"
    echo "[llvm-mov] $(basename "$src")"
    "$CLANG" -m32 -O2 -emit-llvm -S "$src" -o "$TMP/$(basename "$src" .c).ll"
    "$LLC" -verify-machineinstrs "$TMP/$(basename "$src" .c).ll" \
        -mtriple=mov-unknown-linux-gnu -o "$TMP/$(basename "$src" .c).s"
    as --32 -mx86-used-note=no -o "$TMP/$(basename "$src" .c).o" "$TMP/$(basename "$src" .c).s"
    ld -m elf_i386 -static --hash-style=gnu \
        --section-start=.fb13h=0xA0000 --undefined=_fb13h_region \
        "$TMP/_start_llvm.o" "$TMP/$(basename "$src" .c).o" "$TMP/stubs_llvm.o" \
        -o "$out"
    # llvm-mov binaries don't need the symbol table for movie86 to run
    # them (there's no master_loop / dispatch trick to wire up) so
    # strip-all is fine and shaves ~30%.
    strip --strip-all "$out"
    echo "  → $(stat -c %s "$out") B"
}

build_llvm "$HERE/mandelbrot_coarse.c" "$EX/canvas_mandelbrot.elf"
build_llvm "$HERE/mandelbrot_hires.c"  "$EX/canvas_mandelbrot_hires.elf"

echo "done."
