#!/usr/bin/env bash
# Stage-6.5 driver: rustc → llvm-mov-llc → as → ld → run.
#
# The full pipeline is kept here (rather than in the main execution-
# test runner) on purpose — the existing test/Execution/run.sh is for
# .ll fixtures, and mixing in Rust toolchain dependencies would muddy
# its surface. This script consumes main.rs and either prints the
# pipeline asm (default) or runs the linked ELF (`--run`).
#
# Why -mtriple=mov-unknown-linux-gnu is non-optional here:
# rustc emits IR with target triple `i686-unknown-linux-gnu` and data
# layout `e-m:e-p:32:32-...-S128`. Our backend's layout differs in
# `S32` and a few pointer-bank attributes — llvm-mov-llc refuses
# implicit mismatch but honours `-mtriple` as a retarget request, then
# overwrites the layout with ours. The example deliberately stays within
# IR shapes that don't depend on those differences (scalar i32 return,
# no aggregates, no FP), so the retarget is safe.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${BUILD_DIR:-$(cd "$HERE/../.." && pwd)/build}"
DRIVER="${BUILD_DIR}/bin/llvm-mov-llc"

if ! [ -x "$DRIVER" ]; then
    echo "error: $DRIVER not found — run 'make build' first." 1>&2
    exit 2
fi

if ! command -v rustc >/dev/null; then
    echo "error: rustc not found on PATH." 1>&2
    exit 2
fi

# rustc needs the precompiled i686 std/core rlibs even for no_std builds
# (it links nothing, but checks the target). Bail with a clear message
# rather than letting rustc's diagnostic land cold.
if ! rustup target list --installed 2>/dev/null \
        | grep -q '^i686-unknown-linux-gnu$'; then
    cat 1>&2 <<EOF
error: i686-unknown-linux-gnu target not installed.
       rustup target add i686-unknown-linux-gnu
EOF
    exit 2
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

RS="${HERE}/main.rs"
START_S="${HERE}/_start.s"

LL="${WORK}/main.ll"
S="${WORK}/main.s"
O="${WORK}/main.o"
START_O="${WORK}/_start.o"
ELF="${WORK}/main.elf"

# 1. rustc → LLVM IR
#
# edition=2021: the 2024 edition makes `#[no_mangle]` an `unsafe(...)`
# attribute, which complicates the no_std demo without buying us anything.
# Stay on 2021 until the rest of the example needs newer features.
rustc \
    --edition=2021 \
    --crate-type=staticlib \
    --target=i686-unknown-linux-gnu \
    -C panic=abort \
    -C opt-level=0 \
    --emit=llvm-ir \
    -o "$LL" \
    "$RS"

# 2. llvm-mov-llc retargets the i686 IR to the Mov backend.
"$DRIVER" -mtriple=mov-unknown-linux-gnu "$LL" -o "$S"

# 3. as + ld through the standard binutils.
as --32 -o "$O" "$S"
as --32 -o "$START_O" "$START_S"
ld -m elf_i386 -static -e _start -o "$ELF" "$START_O" "$O"

# Default: show what we built. `--run` actually invokes it and checks
# the exit code against the expected 42.
EXPECTED=42

case "${1:-}" in
    --run)
        set +e
        "$ELF"
        exit_code=$?
        set -e
        if [ "$exit_code" = "$EXPECTED" ]; then
            echo "PASS  rust_main  (exit ${exit_code})"
            exit 0
        else
            echo "FAIL  rust_main  (expected ${EXPECTED}, got ${exit_code})"
            exit 1
        fi
        ;;
    "")
        echo "=== generated asm ($S) ==="
        cat "$S"
        echo "=== linked ELF ($ELF) ==="
        file "$ELF"
        echo "(re-run with --run to execute and check exit code = ${EXPECTED})"
        ;;
    *)
        echo "usage: $0 [--run]" 1>&2
        exit 2
        ;;
esac
