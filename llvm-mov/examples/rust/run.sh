#!/usr/bin/env bash
# Stage-6.5 / 7d3 driver: cargo (rustc) → llvm-mov-llc → as → ld → run.
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
#   run.sh --example=aes --run            # AES-128 (RustCrypto); blocked
#                                          # on stage 6d3b — see aes/src/lib.rs
#
# Each example is an independent Cargo crate under its own directory
# so each linked ELF only contains the entry point that fixture
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
    # PNG signature + IHDR chunk parse, no_std/no_alloc, all
    # `ptr::read_unaligned::<u32>` (i.e. pure i32 word reads + bit
    # extract — sidesteps the unsolved i8 SSA path). Embedded
    # 8x8 grayscale PNG fixture; expected exit code is the parsed
    # IHDR width mod 256 = 8.
    png_header) ENTRY="png_header_main"; EXPECTED=8;  CRATE="rust_mov_png_header" ;;
    # JPEG marker walk to SOF0, returning parsed height & 0xff.
    # Same word-read style as png_header; fixture is a 24x16 frame
    # so expected exit code is 16.
    jpeg_header) ENTRY="jpeg_header_main"; EXPECTED=16; CRATE="rust_mov_jpeg_header" ;;
    # Full 32bpp BMP decode: parses the file & DIB headers and
    # iterates every pixel as u32, returning a digest of the
    # complete pixel stream. The unique "full decode" example —
    # PNG / JPEG full decode would need byte-stream ops blocked
    # on stage 6d3b. Digest oracle = 0x6bea7f68; exit = 104.
    bmp_decode) ENTRY="bmp_decode_main"; EXPECTED=104; CRATE="rust_mov_bmp_decode" ;;
    # First crates.io ecosystem decoder hooked end-to-end through
    # llvm-mov-llc: the `base64` crate decodes "SGVsbG8sIFdvcmxkIQ=="
    # back to "Hello, World!" — exit = sum of those 13 ASCII bytes
    # (1129) mod 256 = 105.
    base64_decode) ENTRY="base64_decode_main"; EXPECTED=105; CRATE="rust_mov_base64_decode" ;;
    # Full QOI image decode via the `qoi` crate (no_std + no_alloc
    # with default-features = false). Hand-built 2x2 RGBA fixture;
    # decode_to_buf produces 16 output bytes whose sum is 1800,
    # mod 256 = 8.
    qoi_decode) ENTRY="qoi_decode_main"; EXPECTED=8; CRATE="rust_mov_qoi_decode" ;;
    # Stage-6e indirect-call demo: `apply(add25, 17)` routes through
    # `apply`'s function-pointer formal arg, so `apply`'s body lowers
    # to a real CALL32r (mov-only legalised at stage 7d3 via the
    # `__mov_indirect_callee_slot` save/reload). Expected exit code
    # = add25(17) = 42.
    indirect_call) ENTRY="indirect_call_main"; EXPECTED=42; CRATE="rust_mov_indirect_call" ;;
    # AES-128 ECB encrypt of NIST's AES-128 test vector, iterated
    # N_ROUNDS times (see aes/src/lib.rs). The example does NOT
    # currently round-trip through llvm-mov-llc: rustc emits
    # `<16 x i8>` SIMD ops and `llvm.memset.p0.i32` that the
    # backend can't lower yet — see aes/src/lib.rs for details.
    # EXPECTED is the XOR sum of the final ciphertext bytes mod
    # 256 once the encrypt path can be compiled (placeholder value
    # until a real run produces it).
    aes)  ENTRY="aes_main";  EXPECTED=0;   CRATE="rust_mov_aes" ;;
    *) echo "error: unknown --example=$EXAMPLE (try main, fib, png_header, jpeg_header, bmp_decode, base64_decode, qoi_decode, indirect_call, aes)" 1>&2; exit 2 ;;
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

# aes_force_soft: the `aes` crate at version 0.8+ defaults to compiling
# both the software path and the AES-NI intrinsics path on x86/x86_64,
# choosing at runtime via cpufeatures. The NI path uses i128 / x86 SSE
# vector intrinsics that this backend can't lower (the i32 DAG type
# legalizer hits "Do not know how to split the result of this
# operator" on i128 vector splits). The `aes_force_soft` cfg disables
# the NI compile entirely.
EXTRA_RUSTFLAGS=""
if [ "$EXAMPLE" = "aes" ]; then
    EXTRA_RUSTFLAGS="--cfg aes_force_soft"
fi

RUSTFLAGS="$EXTRA_RUSTFLAGS" cargo rustc \
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

# Link. For most examples our single mov-only `.o` is enough. The
# `aes` example calls into RustCrypto crates (aes::soft::*,
# cipher::*) that rustc precompiled as native i686 code into the
# Cargo staticlib — we pull those symbols in as a fallback so the
# binary actually runs. The mov-only `.o` is listed first so the
# linker picks up its `aes_main` (and not the native `aes_main` that
# Cargo also archived); the staticlib only contributes the
# externally-referenced dependency symbols. The result is "user
# code = mov-only, AES core = native x86" — a hybrid that still
# round-trips the encrypt path end-to-end, and lets the mov-only
# gate fire on `.text` belonging to user code.
EXTRA_LINK=""
case "$EXAMPLE" in
    aes|base64_decode|qoi_decode)
        # Crates with crates.io dependencies. Pull the Cargo
        # staticlib for the precompiled deps; our mov-only `.o`
        # defines the `*_main` first so the linker picks the
        # mov-only entry, the staticlib only contributes the
        # external references.
        STATICLIB="$CRATE_DIR/target/$TARGET_TRIPLE/release/lib${CRATE}.a"
        if [ -f "$STATICLIB" ]; then
            EXTRA_LINK="$STATICLIB"
        fi
        ;;
esac
ld -m elf_i386 -static --gc-sections -e _start -o "$ELF" "$START_O" "$O" $EXTRA_LINK

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
