#!/usr/bin/env bash
# Stage-6.5 / 7d3 driver: cargo (rustc) → llvm-mov-llc → as → ld → run.
#
# Usage:
#   run.sh                    # build main, show asm
#   run.sh --run              # build main, run; expect exit 42
#   run.sh --example=fib      # build fib, show asm
#   run.sh --example=fib --run    # build fib, run; expect exit 32
#                                  # (fib(24)=46368, mod 256)
#
# The two examples are independent Cargo crates under `main/` and
# `fib/` so each linked ELF only contains the entry point that fixture
# exercises (separate compilation unit → cleaner bench numbers when
# comparing per-example shapes).
#
# Cargo emits the staticlib + LLVM IR via `cargo rustc -- --emit=
# llvm-ir,link`. The staticlib is a by-product; we pluck the .ll file
# from `target/i686-unknown-linux-gnu/release/deps/` and feed it to
# llvm-mov-llc.
#
# Why -mtriple=mov-unknown-linux-gnu is mandatory:
# rustc emits `i686-unknown-linux-gnu` + a data layout that differs
# from ours in `S128 vs S32` and a few pointer-bank attributes. The
# driver refuses an implicit mismatch but honours `-mtriple` as a
# retarget request — it then overwrites the layout with ours. Each
# example deliberately stays within IR shapes that don't depend on
# those differences (scalar i32 return, no aggregates, no FP).

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${BUILD_DIR:-$(cd "$HERE/../.." && pwd)/build}"
DRIVER="${BUILD_DIR}/bin/llvm-mov-llc"

# -- arg parsing ---------------------------------------------------------

EXAMPLE="main"
DO_RUN=0
for arg in "$@"; do
    case "$arg" in
        --example=*) EXAMPLE="${arg#--example=}" ;;
        --run)       DO_RUN=1 ;;
        *) echo "usage: $0 [--example={main,fib}] [--run]" 1>&2; exit 2 ;;
    esac
done

case "$EXAMPLE" in
    main) ENTRY="rust_main"; EXPECTED=42; CRATE="rust_mov_main" ;;
    fib)  ENTRY="fib_main";  EXPECTED=32; CRATE="rust_mov_fib" ;;
    *) echo "error: unknown --example=$EXAMPLE (try main, fib)" 1>&2; exit 2 ;;
esac

CRATE_DIR="$HERE/$EXAMPLE"

# -- prerequisites -------------------------------------------------------

if ! [ -x "$DRIVER" ]; then
    echo "error: $DRIVER not found — run 'make build' first." 1>&2
    exit 2
fi
if ! command -v cargo >/dev/null; then
    echo "error: cargo not found on PATH." 1>&2
    exit 2
fi
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

# -- cargo build → LLVM IR ----------------------------------------------

TARGET_TRIPLE="i686-unknown-linux-gnu"

cargo rustc \
    --manifest-path="$CRATE_DIR/Cargo.toml" \
    --release \
    --target="$TARGET_TRIPLE" \
    --quiet \
    -- --emit=llvm-ir,link

# Locate the emitted .ll. Cargo's hashing makes the file name a moving
# target (`<crate>-<hash>.ll`); pick the most recently modified one
# for this crate.
DEPS_DIR="$CRATE_DIR/target/$TARGET_TRIPLE/release/deps"
LL="$(ls -t "$DEPS_DIR"/${CRATE}-*.ll 2>/dev/null | head -1 || true)"
if [ -z "$LL" ] || ! [ -f "$LL" ]; then
    echo "error: emitted .ll not found under $DEPS_DIR" 1>&2
    exit 1
fi

# -- llvm-mov-llc + binutils → ELF --------------------------------------

S="$WORK/$EXAMPLE.s"
O="$WORK/$EXAMPLE.o"
START_S="$CRATE_DIR/_start.s"
START_O="$WORK/_start.o"
ELF="$WORK/$EXAMPLE.elf"

# -verify-machineinstrs catches MIR-level regressions the rust
# example's exit-code check otherwise wouldn't notice.
"$DRIVER" -verify-machineinstrs -mtriple=mov-unknown-linux-gnu "$LL" -o "$S"

as --32 -o "$O" "$S"
as --32 -o "$START_O" "$START_S"
ld -m elf_i386 -static --gc-sections -e _start -o "$ELF" "$START_O" "$O"

# -- run or print --------------------------------------------------------

if [ "$DO_RUN" = "1" ]; then
    set +e
    "$ELF"
    exit_code=$?
    set -e
    if [ "$exit_code" = "$EXPECTED" ]; then
        echo "PASS  $ENTRY  (exit ${exit_code})"
        exit 0
    else
        echo "FAIL  $ENTRY  (expected ${EXPECTED}, got ${exit_code})"
        exit 1
    fi
else
    echo "=== Rust source (${EXAMPLE}) → entry: ${ENTRY} ==="
    echo "=== generated asm ($S) ==="
    cat "$S"
    echo "=== linked ELF ($ELF) ==="
    file "$ELF"
    echo "(re-run with --run to execute and check exit code = ${EXPECTED})"
fi
