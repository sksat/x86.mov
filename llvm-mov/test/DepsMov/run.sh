#!/usr/bin/env bash
# Issue #11 / Option C gate — "deps go through mov too".
#
# Build the dep_mov_add fixture (a tiny bin crate whose body lives
# in a path-local `triv_dep` lib) and assert:
#
#   1. The plain `cargo build --release` succeeds and the resulting
#      binary exits with code 42 — same execution oracle as
#      test/CargoBuild/.
#   2. The linked ELF's .text contains only mov-family mnemonics
#      plus the small handwritten _start.s tail
#      (`call <main>; mov; int 0x80`) and the stage-7 dispatcher's
#      `jmp [next_pc]`.
#
# (2) is what fails before issue #11 lands: triv_dep's native .o
# brings `add`/`ret`/`xchg`/etc. into .text. After cargo-link.sh
# learns to pull each dep crate's LLVM IR (rustc already emits
# `<dep>-<hash>.ll` next to the rlib via --emit=llvm-ir in
# .cargo/config.toml) through llvm-mov-llc, .text should be
# mov-only end to end.
#
# This is intentionally NOT wired into `make test` yet — it goes
# green only after the cargo-link.sh fix.

set -euo pipefail

BUILD_DIR="${1:-build}"
DRIVER_REL="${BUILD_DIR}/bin/llvm-mov-llc"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
EXAMPLES_DIR="$ROOT/examples/rust"

if ! [ -x "$DRIVER_REL" ]; then
    echo "error: $DRIVER_REL not found — run 'make build' first." 1>&2
    exit 2
fi
DRIVER="$(cd "$(dirname "$DRIVER_REL")" && pwd)/$(basename "$DRIVER_REL")"

if ! rustup target list --installed 2>/dev/null | grep -q '^i686-unknown-linux-gnu$'; then
    echo "error: rust target 'i686-unknown-linux-gnu' not installed." 1>&2
    echo "  rustup target add i686-unknown-linux-gnu" 1>&2
    exit 2
fi

export LLVM_MOV_LLC="$DRIVER"

# .text mnemonic allowlist: mov family + the three deliberately
# native fragments we still ship (call/int/jmp explained in the
# header comment above).
ALLOWED='mov|movabs|movzx|movsx|call|int|jmp'

EX_DIR="$EXAMPLES_DIR/dep_mov_add"
EX_BIN="$EX_DIR/target/i686-unknown-linux-gnu/release/rust-mov-dep-mov-add"
EXPECT_EXIT=42

if ! [ -d "$EX_DIR" ]; then
    echo "FAIL  dep_mov_add: fixture dir missing: $EX_DIR"
    exit 1
fi

build_log="/tmp/deps-mov-cargo.log"
(
    cd "$EX_DIR"
    cargo build --release --quiet
) >"$build_log" 2>&1 || {
    echo "FAIL  dep_mov_add: cargo build failed (see $build_log)"
    tail -20 "$build_log" | sed 's/^/  | /'
    exit 1
}

if ! [ -x "$EX_BIN" ]; then
    echo "FAIL  dep_mov_add: binary not produced at $EX_BIN"
    exit 1
fi

set +e
"$EX_BIN"; got=$?
set -e
if [ "$got" != "$EXPECT_EXIT" ]; then
    echo "FAIL  dep_mov_add: expected exit $EXPECT_EXIT, got $got"
    exit 1
fi

violations="$(
    objdump -d -Mintel --no-show-raw-insn -j .text "$EX_BIN" \
        | awk '/^[[:space:]]*[0-9a-f]+:/ { print $2 }' \
        | grep -Ev "^($ALLOWED)$" \
        | sort -u || true
)"

if [ -n "$violations" ]; then
    echo "FAIL  dep_mov_add: non-mov mnemonics in .text:"
    echo "$violations" | sed 's/^/    /'
    exit 1
fi

echo "PASS  dep_mov_add  (exit $got, mov-only .text)"
