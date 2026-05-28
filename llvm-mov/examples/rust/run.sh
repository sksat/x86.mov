#!/usr/bin/env bash
# Dev driver for the per-example Rust → mov-only ELF round-trip.
#
# The actual build is now plain `cargo build --release`: the custom
# linker driver wired in .cargo/config.toml takes the LLVM IR rustc
# emits and runs it through `llvm-mov-llc` + `as --32` + `ld -m elf_i386`.
# This script just picks an example, runs `cargo build` inside its
# crate dir, and either dumps the generated asm or executes the
# binary and checks the expected exit code.
#
# Usage:
#   run.sh                                # build main, show asm
#   run.sh --run                          # build main, run; expect exit 42
#   run.sh --example=fib --run            # fib(24) mod 256 → exit 32
#   run.sh --example=png_header --run     # parse a synthetic PNG IHDR;
#                                          # exit = parsed width = 8
#   run.sh --example=jpeg_header --run    # parse a synthetic JPEG SOF0;
#                                          # exit = parsed height = 16
#   run.sh --example=bmp_decode --run     # full 32bpp BMP decode (pixel
#                                          # stream digest); exit = 104
#   run.sh --example=base64_decode --run  # base64 decode "Hello, World!";
#                                          # exit = 105
#   run.sh --example=qoi_decode --run     # 2x2 RGBA QOI decode; exit = 8
#   run.sh --example=aes --run            # AES-128 (RustCrypto); blocked
#                                          # on stage 6d3b — see aes/src/main.rs
#
# Each example is an independent Cargo crate. Cargo's discovery of
# the shared .cargo/config.toml here (the parent dir) routes the link
# step through cargo-link.sh, which is what makes the binary mov-only.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${BUILD_DIR:-$(cd "$HERE/../.." && pwd)/build}"
# Cargo invokes the linker driver from the crate dir, so any relative
# path the caller passed in here would resolve against the wrong CWD.
if [ -d "$BUILD_DIR" ]; then
    BUILD_DIR="$(cd "$BUILD_DIR" && pwd)"
fi
DRIVER="${BUILD_DIR}/bin/llvm-mov-llc"

EXAMPLE="main"
DO_RUN=0
for arg in "$@"; do
    case "$arg" in
        --example=*) EXAMPLE="${arg#--example=}" ;;
        --run)       DO_RUN=1 ;;
        *) echo "usage: $0 [--example={main,fib,png_header,jpeg_header,bmp_decode,base64_decode,qoi_decode,aes}] [--run]" 1>&2; exit 2 ;;
    esac
done

case "$EXAMPLE" in
    main)          ENTRY="rust_main";          EXPECTED=42;  CRATE="rust-mov-main" ;;
    fib)           ENTRY="fib_main";           EXPECTED=32;  CRATE="rust-mov-fib" ;;
    png_header)    ENTRY="png_header_main";    EXPECTED=8;   CRATE="rust-mov-png-header" ;;
    jpeg_header)   ENTRY="jpeg_header_main";   EXPECTED=16;  CRATE="rust-mov-jpeg-header" ;;
    bmp_decode)    ENTRY="bmp_decode_main";    EXPECTED=104; CRATE="rust-mov-bmp-decode" ;;
    base64_decode) ENTRY="base64_decode_main"; EXPECTED=105; CRATE="rust-mov-base64-decode" ;;
    qoi_decode)    ENTRY="qoi_decode_main";    EXPECTED=8;   CRATE="rust-mov-qoi-decode" ;;
    # Stage-6e indirect-call demo: `apply(add25, 17)` routes through
    # `apply`'s function-pointer formal arg, so `apply`'s body lowers
    # to a real CALL32r (mov-only legalised at stage 7d3 via the
    # `__mov_indirect_callee_slot` save/reload). Expected exit code
    # = add25(17) = 42.
    indirect_call) ENTRY="indirect_call_main"; EXPECTED=42;  CRATE="rust-mov-indirect-call" ;;
    # AES-128 ECB encrypt of NIST's AES-128 test vector. Doesn't yet
    # round-trip through llvm-mov-llc — see aes/src/main.rs. EXPECTED is
    # a placeholder until the encrypt path can be compiled.
    aes)           ENTRY="aes_main";           EXPECTED=0;   CRATE="rust-mov-aes" ;;
    *) echo "error: unknown --example=$EXAMPLE" 1>&2; exit 2 ;;
esac

CRATE_DIR="$HERE/$EXAMPLE"

if ! [ -x "$DRIVER" ]; then
    echo "error: $DRIVER not found — run 'make build' first." 1>&2
    exit 2
fi

# Surface the i686 rust-std prerequisite up front rather than letting
# cargo print its slightly cryptic "can't find crate for `core`".
if ! rustup target list --installed 2>/dev/null | grep -q '^i686-unknown-linux-gnu$'; then
    echo "error: rust target 'i686-unknown-linux-gnu' not installed." 1>&2
    echo "  rustup target add i686-unknown-linux-gnu" 1>&2
    exit 2
fi

export LLVM_MOV_LLC="$DRIVER"

# Plain cargo build — the linker driver wired in .cargo/config.toml
# does the llvm-mov-llc + as + ld dance and writes both the binary
# and (as a side artefact) the generated asm to target/.../release/.
(cd "$CRATE_DIR" && cargo build --release --quiet)

ELF="$CRATE_DIR/target/i686-unknown-linux-gnu/release/$CRATE"
# The linker driver writes the .s next to its rustc-supplied -o
# target — that lives under deps/<crate>-<hash>.s. Pick the most
# recently modified one for this crate.
DEPS_S_DIR="$CRATE_DIR/target/i686-unknown-linux-gnu/release/deps"
S="$(ls -t "$DEPS_S_DIR"/*.s 2>/dev/null | head -1 || true)"

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
    if [ -f "$S" ]; then cat "$S"; else echo "(no asm written — the linker driver should leave $S behind)"; fi
    echo "=== linked ELF ($ELF) ==="
    file "$ELF"
    echo "(re-run with --run to execute and check exit code = ${EXPECTED})"
fi
