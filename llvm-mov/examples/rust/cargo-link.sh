#!/usr/bin/env bash
# Custom linker driver invoked by cargo via examples/rust/.cargo/config.toml.
#
# Rustc has already compiled the crate to LLVM IR (.ll) and a native
# .o, and is now calling us with the linker invocation it would
# normally pass to the host's `cc` / `ld`. We *ignore* the native .o
# and instead:
#
#   1. Find the freshly-emitted .ll under
#      target/<triple>/release/deps/<crate>-<hash>.ll
#   2. Run llvm-mov-llc to produce mov-only x86-32 asm.
#   3. Assemble that asm + the crate's _start.s with `as --32`.
#   4. Pull native .o files out of any .rlib that rustc handed us as a
#      link input — these are the dependency crates that we *don't*
#      try to push through llvm-mov-llc (deps frequently use IR shapes
#      the backend can't lower yet; the existing run.sh hybrid does the
#      same thing).
#   5. `ld -m elf_i386 -static -e _start` everything together, writing
#      to the `-o <output>` path cargo asked for.
#
# Env vars (for development; defaults assume a `make build` checkout):
#   LLVM_MOV_LLC          — path to the driver binary
#   LLVM_MOV_LLC_FLAGS    — extra flags to llvm-mov-llc (default: -verify-machineinstrs)
#
# Invariants:
#   - CWD is the crate dir (cargo invokes the linker from where `cargo
#     build` was run; users `cd <crate> && cargo build`).
#   - The crate dir contains `_start.s`.

set -euo pipefail

CRATE_DIR="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LLVM_MOV_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
DRIVER="${LLVM_MOV_LLC:-$LLVM_MOV_DIR/build/bin/llvm-mov-llc}"
DRIVER_FLAGS="${LLVM_MOV_LLC_FLAGS:--verify-machineinstrs}"

if ! [ -x "$DRIVER" ]; then
    echo "cargo-link.sh: llvm-mov-llc not found at $DRIVER" 1>&2
    echo "  (set LLVM_MOV_LLC=<abs path>, or build the backend with 'make -C $LLVM_MOV_DIR build')" 1>&2
    exit 2
fi

# ---- parse cargo's linker invocation ---------------------------------
# We need:
#   - `-o <output>` → final ELF path cargo expects
#   - `*.rlib` inputs → dependency archives (for hybrid link)
# Everything else (rustc's runtime .o, -L paths, -l libs, link args)
# is discarded; we're building a static no-libc ELF.
OUTPUT=""
RLIBS=()
while [ $# -gt 0 ]; do
    case "$1" in
        -o)
            OUTPUT="$2"; shift 2 ;;
        -o*)
            OUTPUT="${1#-o}"; shift ;;
        *.rlib)
            RLIBS+=("$1"); shift ;;
        *)
            shift ;;
    esac
done

if [ -z "$OUTPUT" ]; then
    echo "cargo-link.sh: no -o <output> in linker args" 1>&2
    exit 2
fi

# ---- locate the rustc-emitted .ll ------------------------------------
# Rustc emits .ll alongside the .o it hands cargo to link, in the
# `--out-dir` cargo configured (= target/<triple>/{release,debug}/deps).
# Same basename as our OUTPUT, just .ll extension — robust even when
# the crate also produces a sibling staticlib that drops a .ll for the
# bench's rustc-native reference column.
LL="$OUTPUT.ll"
if ! [ -f "$LL" ]; then
    # Fallback: pick the freshest .ll in the same dir. Keeps the
    # driver working if a future rustc layout change moves the .ll
    # next to the bin output instead of next to the rcgu .o.
    DEPS_DIR="$(dirname "$OUTPUT")"
    LL="$(ls -t "$DEPS_DIR"/*.ll 2>/dev/null | head -1 || true)"
fi
if [ -z "$LL" ] || ! [ -f "$LL" ]; then
    echo "cargo-link.sh: no .ll found at $OUTPUT.ll or under $(dirname "$OUTPUT")" 1>&2
    echo "  (check that .cargo/config.toml passes --emit=llvm-ir to rustc)" 1>&2
    exit 2
fi

START_S="$CRATE_DIR/_start.s"
if ! [ -f "$START_S" ]; then
    echo "cargo-link.sh: $START_S missing — every example needs a hand-written _start.s" 1>&2
    exit 2
fi

# ---- mov-only pipeline ------------------------------------------------
# Persist the generated asm next to the binary so dev tooling
# (examples/rust/run.sh without --run, bench scripts, ad-hoc diffing)
# can pick it up without re-running llvm-mov-llc. Object files are
# transient — only the .s is interesting to a human reader.
S="$OUTPUT.s"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
O="$WORK/crate.o"
START_O="$WORK/_start.o"

"$DRIVER" $DRIVER_FLAGS -mtriple=mov-unknown-linux-gnu "$LL" -o "$S"
as --32 -o "$O" "$S"
as --32 -o "$START_O" "$START_S"

# Extract native .o members from each dep rlib so `ld` can resolve
# externally-referenced symbols (RustCrypto, base64, qoi, ...). Each
# rlib is an `ar` archive; rustc embeds at least one native .o member.
EXTRA_OBJS=()
i=0
for rlib in "${RLIBS[@]}"; do
    [ -f "$rlib" ] || continue
    dir="$WORK/rlib-$i"
    mkdir -p "$dir"
    (cd "$dir" && ar x "$rlib" 2>/dev/null || true)
    while IFS= read -r -d '' obj; do
        EXTRA_OBJS+=("$obj")
    done < <(find "$dir" -maxdepth 1 -name '*.o' -print0)
    i=$((i+1))
done

mkdir -p "$(dirname "$OUTPUT")"
ld -m elf_i386 -static --gc-sections -e _start \
    -o "$OUTPUT" \
    "$START_O" "$O" "${EXTRA_OBJS[@]}"
