#!/usr/bin/env bash
# Build both flavours of `canvas_mandelbrot*.elf` from one C source.
#
#   mandelbrot.c → (movfuscator pipeline) → canvas_mandelbrot_mov.elf
#   mandelbrot.c → (clang -O2 → llvm-mov-llc) → canvas_mandelbrot.elf
#
# Both flavours are statically linked, ship a `.fb13h` BSS region at
# guest address 0xA0000 (mode 13h), and rely on a small `set_video_mode`
# stub that wraps `int 0x10` (AH=0, AL=mode).
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

# ============================================================
# movfuscator pipeline → canvas_mandelbrot_mov.elf
# ============================================================
echo "[movfuscator] preprocess + rcc + as + ld"
"$ROOT/movfuscator-wasm/scripts/preprocess.sh" "$HERE/mandelbrot.c" "$TMP/m.i" >/dev/null
"$B/rcc" -target=x86/mov "$TMP/m.i" "$TMP/m.s"
as --32 -mx86-used-note=no -o "$TMP/m.o" "$TMP/m.s" 2>/dev/null
as --32 -mx86-used-note=no -o "$TMP/stubs.o" "$HERE/stubs_movfuscator.s"
ld -m elf_i386 -static --hash-style=gnu \
    --section-start=.fb13h=0xA0000 --undefined=_fb13h_region \
    "$B/crt0.o" "$TMP/m.o" "$B/crtf.o" "$B/crtd.o" "$SF/softfloat32.o" "$TMP/stubs.o" \
    -o "$EX/canvas_mandelbrot_mov.elf"
strip --strip-all "$EX/canvas_mandelbrot_mov.elf"
echo "  → $(stat -c %s "$EX/canvas_mandelbrot_mov.elf") B"

# ============================================================
# llvm-mov pipeline → canvas_mandelbrot.elf
# ============================================================
echo "[llvm-mov] clang -O2 → llvm-mov-llc → as + ld"
"$CLANG" -m32 -O2 -emit-llvm -S "$HERE/mandelbrot.c" -o "$TMP/m.ll"
"$LLC" -verify-machineinstrs "$TMP/m.ll" -mtriple=mov-unknown-linux-gnu -o "$TMP/m.s"
as --32 -mx86-used-note=no -o "$TMP/m.o" "$TMP/m.s"
as --32 -mx86-used-note=no -o "$TMP/stubs.o" "$HERE/stubs_llvm.s"
as --32 -mx86-used-note=no -o "$TMP/_start.o" "$HERE/_start_llvm.s"
ld -m elf_i386 -static --hash-style=gnu \
    --section-start=.fb13h=0xA0000 --undefined=_fb13h_region \
    "$TMP/_start.o" "$TMP/m.o" "$TMP/stubs.o" \
    -o "$EX/canvas_mandelbrot.elf"
strip --strip-all "$EX/canvas_mandelbrot.elf"
echo "  → $(stat -c %s "$EX/canvas_mandelbrot.elf") B"

echo "done."
