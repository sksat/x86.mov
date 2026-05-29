#!/usr/bin/env bash
# Build examples/input_demo.elf from input_demo.c via the llvm-mov
# pipeline (clang -emit-llvm -> llvm-mov-llc -> mov-target asm).
#
# Why llvm-mov rather than movfuscator: llvm-mov emits ordinary jmp/call
# control flow (no SIGILL master_loop dispatch), so the same ELF runs
# *natively* on turbo86 as well as on movie86 — letting input_demo
# exercise turbo86's WS key input, not just the browser path. (The
# movfuscator build only ran on movie86; turbo86 hit the unhandled-
# SIGSEGV dispatch wall — see the issue on running movfuscator output
# natively on turbo86.)
#
#   input_demo.c -> clang -emit-llvm -> llvm-mov-llc -> .s -> .o
#   link: _start_llvm.o + input_demo.o + stubs_llvm.o, .fb13h @ 0xA0000
#
# Requires movie86's jmp-rel8 (EB) decode to run on movie86: gas relaxes
# the dispatcher jumps to the 2-byte EB form.
#
# Prereqs: llvm-mov-llc built (cd ../../../llvm-mov && make build, or on
# Arch: make build LLVM_CONFIG=llvm-config), clang (clang-22), binutils
# `as --32` + `ld -m elf_i386`.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"

EX="$HERE/.."
CLANG="${CLANG:-clang-22}"
LLC="${LLC:-$ROOT/llvm-mov/build/bin/llvm-mov-llc}"

if [ ! -x "$LLC" ]; then
    echo "llvm-mov-llc not found at $LLC — build it first (see header)" >&2
    exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "[llvm-mov] input_demo.c"
"$CLANG" -m32 -O2 -emit-llvm -S "$HERE/input_demo.c" -o "$TMP/input_demo.ll"
"$LLC" -verify-machineinstrs "$TMP/input_demo.ll" -mtriple=mov-unknown-linux-gnu -o "$TMP/input_demo.s"

as --32 -mx86-used-note=no -o "$TMP/input_demo.o" "$TMP/input_demo.s"
as --32 -mx86-used-note=no -o "$TMP/_start_llvm.o" "$HERE/_start_llvm.s"
as --32 -mx86-used-note=no -o "$TMP/stubs_llvm.o" "$HERE/stubs_llvm.s"

ld -m elf_i386 -static --hash-style=gnu \
    --section-start=.fb13h=0xA0000 --undefined=_fb13h_region \
    "$TMP/_start_llvm.o" "$TMP/input_demo.o" "$TMP/stubs_llvm.o" \
    -o "$EX/input_demo.elf"
strip --strip-all "$EX/input_demo.elf"
echo "  → $(stat -c %s "$EX/input_demo.elf") B"
