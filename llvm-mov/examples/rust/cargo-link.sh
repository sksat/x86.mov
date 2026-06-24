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
#   4. For each dep rlib (issue #11 / Option C):
#      a. Look for a sibling `<crate>-<hash>.ll` next to the rlib —
#         present for any dep rustc compiled fresh under our
#         `--emit=llvm-ir` rustflags (path deps, crates.io, etc.).
#      b. If present, try `llvm-mov-llc` + `as --32` on it. On
#         success use that mov-only .o for the link.
#      c. On any failure (no sibling IR, llc abort, as error) fall
#         back to the rlib's native .o member(s) extracted via
#         `ar x` — same hybrid path this script shipped originally.
#      Granularity is per-rlib (= per dep crate): if a crate doesn't
#      round-trip we keep its whole .o native rather than mixing
#      mov / native fragments inside one crate's symbols.
#   5. `ld -m elf_i386 -static -e _start` everything together, writing
#      to the `-o <output>` path cargo asked for.
#
# A per-build status report of which dep crates went mov-only vs
# fell back is written next to the binary as `<OUTPUT>.deps-status`,
# one line per rlib (`mov <crate>` / `native(<reason>) <crate>`).
# That's what the bench's "mov-able deps / total deps" column reads.
#
# Env vars (for development; defaults assume a `make build` checkout):
#   LLVM_MOV_LLC          — path to the driver binary
#   LLVM_MOV_LLC_FLAGS    — extra flags to llvm-mov-llc (default: -verify-machineinstrs)
#   LLVM_MOV_LLC_DEP_TIMEOUT
#                         — per-dep-rlib wall-clock budget, in seconds, for
#                           the mov-only lower attempt (default: 60). A dep
#                           whose IR lowers in principle but blows the
#                           mov-only legalize pass up to an impractical
#                           runtime (e.g. crates.io `base64`: a single large
#                           function whose byte-chain rewrite expands
#                           super-linearly — issue #11 follow-up) is killed
#                           at this budget and falls back to its native .o,
#                           logged as `native(llc-timeout)`. Set to 0 to
#                           disable the budget (run llc unbounded). Only
#                           deps are bounded; the user crate's own llc run
#                           (hand-written examples) is always unbounded.
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
DEP_TIMEOUT="${LLVM_MOV_LLC_DEP_TIMEOUT:-60}"

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

# ---- per-dep mov-or-native loop --------------------------------------
# Each rlib is treated as one crate (with rustflags
# `-Ccodegen-units=1` in our .cargo/config.toml that's also one .o
# member). If rustc dropped a sibling `<crate>-<hash>.ll` next to
# the rlib we try to drive *that* through llvm-mov-llc; otherwise
# (or on any failure) we use the native .o from the rlib via
# `ar x` — the same hybrid path this driver shipped before issue
# #11. The status of each rlib is logged to <OUTPUT>.deps-status.
EXTRA_OBJS=()
STATUS="$OUTPUT.deps-status"
: > "$STATUS"

# Try to mov-lower one rlib. Echoes the path to a mov-only .o on
# success, empty string on failure (with a reason written to STATUS).
try_mov_lower_rlib() {
    local rlib="$1" outdir="$2"
    local rlib_dir base crate hash sibling_ll
    rlib_dir="$(dirname "$rlib")"
    base="$(basename "$rlib" .rlib)"        # libtriv_dep-<hash>
    base="${base#lib}"                       # triv_dep-<hash>
    crate="${base%-*}"
    hash="${base##*-}"
    sibling_ll="$rlib_dir/${crate}-${hash}.ll"

    if ! [ -f "$sibling_ll" ]; then
        printf 'native(no-ir) %s\n' "$crate" >> "$STATUS"
        return 1
    fi

    local dep_s="$outdir/${crate}.mov.s"
    local dep_o="$outdir/${crate}.mov.o"
    local llc_log="$outdir/${crate}.llc.log"
    local as_log="$outdir/${crate}.as.log"
    # Bound the mov-only lower attempt: a lowerable-in-principle dep can
    # still drive the legalize pass to an impractical runtime (issue #11
    # follow-up). `timeout` exits 124 when the budget is hit; we map that
    # to a distinct `native(llc-timeout)` status so the deps-status
    # report distinguishes "the backend can't lower this" (llc-fail) from
    # "the backend lowers it too slowly to be practical" (llc-timeout).
    # DEP_TIMEOUT=0 disables the budget (bare driver invocation).
    local llc_rc=0
    if [ "$DEP_TIMEOUT" = "0" ]; then
        "$DRIVER" $DRIVER_FLAGS -mtriple=mov-unknown-linux-gnu \
            "$sibling_ll" -o "$dep_s" 2>"$llc_log" || llc_rc=$?
    else
        timeout "$DEP_TIMEOUT" "$DRIVER" $DRIVER_FLAGS \
            -mtriple=mov-unknown-linux-gnu \
            "$sibling_ll" -o "$dep_s" 2>"$llc_log" || llc_rc=$?
    fi
    if [ "$llc_rc" -ne 0 ]; then
        if [ "$llc_rc" -eq 124 ]; then
            printf 'native(llc-timeout) %s\n' "$crate" >> "$STATUS"
        else
            printf 'native(llc-fail) %s\n' "$crate" >> "$STATUS"
        fi
        return 1
    fi
    if ! as --32 -o "$dep_o" "$dep_s" 2>"$as_log"; then
        printf 'native(as-fail) %s\n' "$crate" >> "$STATUS"
        return 1
    fi
    printf 'mov %s\n' "$crate" >> "$STATUS"
    printf '%s' "$dep_o"
}

i=0
for rlib in "${RLIBS[@]}"; do
    [ -f "$rlib" ] || continue
    dir="$WORK/rlib-$i"
    mkdir -p "$dir"

    if mov_obj="$(try_mov_lower_rlib "$rlib" "$dir")" && [ -n "$mov_obj" ]; then
        EXTRA_OBJS+=("$mov_obj")
    else
        # Native fallback: extract every .o member from the rlib.
        (cd "$dir" && ar x "$rlib" 2>/dev/null || true)
        while IFS= read -r -d '' obj; do
            EXTRA_OBJS+=("$obj")
        done < <(find "$dir" -maxdepth 1 -name '*.o' -print0)
    fi
    i=$((i+1))
done

mkdir -p "$(dirname "$OUTPUT")"
ld -m elf_i386 -static --gc-sections -e _start \
    -o "$OUTPUT" \
    "$START_O" "$O" "${EXTRA_OBJS[@]}"
