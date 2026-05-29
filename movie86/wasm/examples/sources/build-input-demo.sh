#!/usr/bin/env bash
# Build examples/input_demo.elf from input_demo.c via the movfuscator
# pipeline (mov-only x86), statically linked against the movfuscator
# runtime + the shared stubs (set_video_mode / mmap_request / exit /
# poll_input) and the .fb13h framebuffer region pinned at 0xA0000.
#
# Integer-only demo — no softfloat needed (unlike the Mandelbrot
# builds), so this links just crt0/crtf/crtd + stubs.
#
#   input_demo.c → (movfuscator) → input_demo.elf
#
# **Don't `--strip-all`** — movie86 wires SIGSEGV→dispatch and
# SIGILL→master_loop from the ELF symbol table; strip-all kills the
# symtab and the NULL-deref dispatch trick stops working. --strip-debug
# is fine.
#
# Prereqs:
#   - movfuscator-wasm/vendor built (`make -C movfuscator-wasm setup build-native`)
#   - binutils with `as --32` + `ld -m elf_i386`

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"

EX="$HERE/.."
B="$ROOT/movfuscator-wasm/vendor/movfuscator/build"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

as --32 -mx86-used-note=no -o "$TMP/stubs_mov.o" "$HERE/stubs_movfuscator.s"

echo "[movfuscator] input_demo.c"
"$ROOT/movfuscator-wasm/scripts/preprocess.sh" "$HERE/input_demo.c" "$TMP/input_demo.i" >/dev/null
"$B/rcc" -target=x86/mov "$TMP/input_demo.i" "$TMP/input_demo.s"
as --32 -mx86-used-note=no -o "$TMP/input_demo.o" "$TMP/input_demo.s" 2>/dev/null
ld -m elf_i386 -static --hash-style=gnu \
    --section-start=.fb13h=0xA0000 --undefined=_fb13h_region \
    "$B/crt0.o" "$TMP/input_demo.o" "$B/crtf.o" "$B/crtd.o" "$TMP/stubs_mov.o" \
    -o "$EX/input_demo.elf"
strip --strip-debug "$EX/input_demo.elf"
echo "  → $(stat -c %s "$EX/input_demo.elf") B"
