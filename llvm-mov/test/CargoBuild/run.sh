#!/usr/bin/env bash
# Plain `cargo build` (no run.sh wrapper) → runnable mov-only ELF.
#
# Each Rust example under ../../examples/rust/<name>/ should be buildable
# with just `cd <name> && cargo build --release` (the casual workflow a
# Rust user expects). The custom linker driver registered in
# examples/rust/.cargo/config.toml takes over the link step, drives
# llvm-mov-llc + as + ld, and writes the final ELF into Cargo's
# target/ directory.
#
# This harness asserts the resulting binary exits with the expected
# code — same oracle as test/Execution/ and examples/rust/run.sh.

set -euo pipefail

BUILD_DIR="build"
ONLY=""
for arg in "$@"; do
    case "$arg" in
        --only=*) ONLY="${arg#--only=}" ;;
        --*)      echo "unknown flag: $arg" 1>&2; exit 2 ;;
        *)        BUILD_DIR="$arg" ;;
    esac
done

DRIVER="${BUILD_DIR}/bin/llvm-mov-llc"
HERE="$(cd "$(dirname "$0")" && pwd)"
EXAMPLES_DIR="$(cd "$HERE/../../examples/rust" && pwd)"

if ! [ -x "$DRIVER" ]; then
    echo "error: $DRIVER not found — run 'make build' first." 1>&2
    exit 2
fi

# Surface the i686 rust-std prerequisite the same way examples/rust/run.sh
# does (terse, with the one-line install hint).
if ! rustup target list --installed 2>/dev/null | grep -q '^i686-unknown-linux-gnu$'; then
    echo "error: rust target 'i686-unknown-linux-gnu' not installed." 1>&2
    echo "  rustup target add i686-unknown-linux-gnu" 1>&2
    exit 2
fi

export LLVM_MOV_LLC="$(cd "$BUILD_DIR/bin" && pwd)/llvm-mov-llc"

declare -A EXPECTED=(
    [main]=42
    [fib]=32
    [dep_mov_add]=42
    [png_header]=8
    [jpeg_header]=16
    [bmp_decode]=104
    [base64_decode]=105
    [qoi_decode]=8
    [indirect_call]=42
)

# `aes` doesn't yet round-trip through llvm-mov-llc (see run.sh comment);
# it stays exercised by the existing run.sh smoke test, not this one.
EXAMPLES=("${!EXPECTED[@]}")
# Sort for deterministic output.
IFS=$'\n' EXAMPLES=($(sort <<<"${EXAMPLES[*]}")); unset IFS

pass=0
fail=0
for ex in "${EXAMPLES[@]}"; do
    if [ -n "$ONLY" ] && [ "$ex" != "$ONLY" ]; then continue; fi
    expect="${EXPECTED[$ex]}"
    crate_dir="$EXAMPLES_DIR/$ex"
    if ! [ -d "$crate_dir" ]; then
        echo "FAIL  $ex  (crate dir missing: $crate_dir)"
        fail=$((fail+1)); continue
    fi

    # Plain cargo build — no extra flags, no env tweaks, no rustflags from
    # the caller. The plumbing must come from .cargo/config.toml + the
    # custom linker driver. That's the whole point of this gate.
    (
        cd "$crate_dir"
        cargo build --release --quiet 2>&1
    ) >"/tmp/cargo-build-$ex.log" 2>&1 || {
        echo "FAIL  $ex  (cargo build failed; see /tmp/cargo-build-$ex.log)"
        tail -20 "/tmp/cargo-build-$ex.log" | sed "s/^/  | /"
        fail=$((fail+1)); continue
    }

    # Cargo writes binary crates to target/<triple>/release/<name>.
    # The crate `name` in Cargo.toml is hyphenated (`rust-mov-<ex>`),
    # so directories like `png_header` map to `rust-mov-png-header`.
    ex_hyphen="${ex//_/-}"
    elf="$crate_dir/target/i686-unknown-linux-gnu/release/rust-mov-$ex_hyphen"
    if ! [ -x "$elf" ]; then
        echo "FAIL  $ex  (binary not found: $elf)"
        fail=$((fail+1)); continue
    fi

    set +e
    "$elf"
    got=$?
    set -e
    if [ "$got" = "$expect" ]; then
        echo "PASS  $ex  (exit $got)"
        pass=$((pass+1))
    else
        echo "FAIL  $ex  (expected $expect, got $got)"
        fail=$((fail+1))
    fi
done

echo "--- $pass passed, $fail failed ---"
[ "$fail" = 0 ]
