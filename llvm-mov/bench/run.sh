#!/usr/bin/env bash
# bench/run.sh — side-by-side comparison of llvm-mov-llc vs movfuscator,
# plus a "llvm-mov on Rust" column for the Cargo-backed examples under
# examples/rust/{main,fib}/.
#
# C fixtures are built through both back-ends from the *same* source
# under bench/fixtures/ or movfuscator-wasm/tests/fixtures/. Rust
# fixtures only go through llvm-mov (movfuscator is C-only); their
# movfuscator column is rendered as `—`.
#
# Metrics per row:
#   - total ELF size                 (`stat -c %s`)
#   - .text section size             (`size --format=sysv`)
#   - .rodata section size           (--gc-sections drops llvm-mov's add
#                                     tables when unused, so the data
#                                     overhead is fixture-dependent)
#   - mov ratio                      (mov mnemonics / total instructions in
#                                     .text — 1.0 = fully mov-only)
#   - non-mov mnemonic counts        (which opcodes are still in the .text)
#
# llvm-mov pipeline (C):
#   clang -m32 -emit-llvm -S → llvm-mov-llc -mtriple=mov-... → as --32 → ld
#
# llvm-mov pipeline (Rust):
#   cargo rustc --release --target=i686-unknown-linux-gnu -- --emit=llvm-ir
#       → pluck .ll from target/<triple>/release/deps/
#       → llvm-mov-llc -mtriple=mov-... → as --32 → ld
#
# movfuscator pipeline:
#   movcc <fixture.c> -o <ELF>    (statically resolved by movfuscator's
#                                  build.sh; binary is dynamically linked
#                                  against the system 32-bit libc)
#
# Output is written to bench/results.md, overwriting any previous run.
# This file is committed for diffability across PRs and CI.

set -euo pipefail

# -- paths ---------------------------------------------------------------

HERE="$(cd "$(dirname "$0")" && pwd)"
LLVM_MOV_DIR="$(cd "$HERE/.." && pwd)"
ROOT="$(cd "$LLVM_MOV_DIR/.." && pwd)"
MOVFUSCATOR_WASM="$ROOT/movfuscator-wasm"

# Fixture lookup: a name resolves to the first match in this search
# order, so llvm-mov-specific fixtures live alongside the bench (in
# bench/fixtures/) and override the shared movfuscator-wasm test set
# if a name collides. Shared fixtures (return0, return42, etc.) stay
# in movfuscator-wasm/tests/fixtures so both subprojects test against
# the same C source.
FIXTURE_DIRS=(
    "$HERE/fixtures"
    "$MOVFUSCATOR_WASM/tests/fixtures"
)

# Resolve <name> → absolute path to <name>.c, or empty string.
resolve_fixture() {
    local name="$1" dir
    for dir in "${FIXTURE_DIRS[@]}"; do
        if [ -f "$dir/$name.c" ]; then
            printf '%s\n' "$dir/$name.c"
            return
        fi
    done
    printf '\n'
}

BUILD_DIR="${BUILD_DIR:-$LLVM_MOV_DIR/build}"
LLVM_MOV_LLC="$BUILD_DIR/bin/llvm-mov-llc"
MOVCC="$MOVFUSCATOR_WASM/vendor/movfuscator/build/movcc"

CLANG="${CLANG:-clang-22}"

# -- fixture selection ---------------------------------------------------

# Default set: single-file fixtures that both pipelines build end-to-end.
# Each fixture targets a different legalize-stage surface so bench-check
# can show the effect of each future change in isolation:
#
#   return0/return42  — trivial floor. Almost no work for either backend;
#                       shows fixed-overhead difference (4.6 KiB vs 10 MiB).
#   eq42              — pure `==` comparison. Exercises stage 7c2
#                       (CMP+Jcc EQ/NE legalize). After 7c2 the function
#                       body has no cmp/je/jne — only mov + dispatcher jmp.
#   bitops            — bitwise AND/XOR/OR chain. Exercises stage 7b1
#                       (per-op byte tables). No control flow.
#   sum10             — arithmetic loop. Exercises stage 7a (ADD32 byte
#                       chain) heavily and links the 256 KiB add tables.
#                       Has signed cmp+jg (loop bound) that stage 7c4 will
#                       legalize.
#   fib10             — small Fibonacci loop. ADD32rr chain + signed
#                       compare; same story as sum10 but with an extra
#                       loop carried dependency (a/b/t).
#   shifts            — `<<`/`>>` with constant amounts. Exercises stage
#                       7b2 (SHL32ri / SHR32ri byte-table rewrite).
#   shift_reg         — `<<`/`>>` with a runtime amount, covering
#                       SHL32rCL, SAR32rCL and SHR32rCL in one fixture.
#                       Surfaces the opt-6-follow-up "Phase 5 idx-zero
#                       hoist for shift32rCL": each shift site historically
#                       paid 50 redundant `mov dword [idx], 0` stores;
#                       with the hoist, 1.
DEFAULT_FIXTURES=(
    return0
    return42
    eq42
    lt_unsigned
    bitops
    sum10
    fib10
    shifts
    shift_reg
    fib_rec
    multi_call
)

# Rust fixtures live in their own Cargo crates under examples/rust/.
# Each entry's metadata (crate dir, expected exit code, entry symbol,
# crate name as cargo writes it into target/.../deps/<crate>-<hash>.ll)
# is encoded in the per-fixture build path inside the main loop.
RUST_FIXTURES=(
    rust_main
    rust_fib
)

if [ $# -gt 0 ]; then
    FIXTURE_NAMES=("$@")
else
    FIXTURE_NAMES=("${DEFAULT_FIXTURES[@]}" "${RUST_FIXTURES[@]}")
fi

# -- prerequisites -------------------------------------------------------

for required in "$LLVM_MOV_LLC" "$MOVCC" "$CLANG"; do
    if ! command -v "$required" >/dev/null 2>&1 && [ ! -x "$required" ]; then
        echo "error: required tool '$required' missing" >&2
        echo "  llvm-mov-llc: run 'make -C $LLVM_MOV_DIR build'" >&2
        echo "  movcc:        run 'make -C $MOVFUSCATOR_WASM setup build-native'" >&2
        echo "  clang:        set CLANG=<path> or install clang-22" >&2
        exit 1
    fi
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# -- helpers -------------------------------------------------------------

# count_mov_ratio <ELF> → "<mov_count> <total_count> <ratio_percent>"
#
# `objdump -j .text` restricts disassembly to the user-code section,
# excluding linker-generated stubs (`.plt`, `.init`, `.fini`, ELF entry
# trampolines) that would otherwise inflate the count and corrupt the
# comparison — movfuscator's binary in particular embeds a sizeable
# runtime in non-.text executable sections.
count_mov_ratio() {
    local elf="$1"
    local mnem
    mnem="$(objdump -d -Mintel --no-show-raw-insn -j .text "$elf" 2>/dev/null \
        | awk '/^[[:space:]]*[0-9a-f]+:/ { print $2 }')"
    local total
    total="$(printf '%s\n' "$mnem" | grep -c .)"
    local movs
    movs="$(printf '%s\n' "$mnem" | grep -cE '^(mov|movabs|movzx|movsx)$' || true)"
    local ratio="n/a"
    if [ "$total" -gt 0 ]; then
        ratio="$(awk -v m="$movs" -v t="$total" 'BEGIN{printf "%.1f%%", (m/t)*100}')"
    fi
    printf '%d %d %s\n' "$movs" "$total" "$ratio"
}

# non_mov_mnemonics <ELF> → space-separated list of unique non-mov opcodes
# (also `.text`-only, same rationale as count_mov_ratio).
non_mov_mnemonics() {
    local elf="$1"
    objdump -d -Mintel --no-show-raw-insn -j .text "$elf" 2>/dev/null \
        | awk '/^[[:space:]]*[0-9a-f]+:/ { print $2 }' \
        | grep -vE '^(mov|movabs|movzx|movsx)$' \
        | sort -u \
        | paste -sd' ' -
}

# measure_runtime <ELF> → mean wall-clock time in milliseconds, or
# "n/a" if hyperfine isn't available. We use `--shell=none` to avoid
# shell-init overhead, and `--warmup 2 --runs 20` for tight short-
# program timing (the fixtures here are mostly sub-millisecond).
#
# Caveat for movfuscator-compiled binaries on this host: their exit
# code is always 1 (not main's return value) due to an upstream
# crt/exit-path quirk, but the computation itself runs to completion
# — stdout is correct, runtime is meaningful, only the post-main
# exit-code linkage is broken. hyperfine's `-i` ignores the
# non-zero exit so we still get a runtime number.
measure_runtime() {
    local elf="$1"
    if ! command -v hyperfine >/dev/null 2>&1; then
        printf 'n/a\n'
        return
    fi
    # Hyperfine writes both human-readable benchmark text and the JSON
    # export to stdout, so we point the export at a temp file and
    # silence the textual output.
    local hf_json="$WORK/hf-$$-$RANDOM.json"
    if ! hyperfine --shell=none --warmup 2 --runs 20 -i \
            --export-json "$hf_json" -- "$elf" >/dev/null 2>&1; then
        printf 'n/a\n'
        return
    fi
    local mean
    mean="$(grep -oE '"mean":[[:space:]]*[0-9.eE+-]+' "$hf_json" \
        | head -1 \
        | grep -oE '[0-9.eE+-]+$')"
    rm -f "$hf_json"
    if [ -z "$mean" ]; then
        printf 'n/a\n'
    else
        # hyperfine reports seconds; convert to ms with 3 decimals.
        awk -v s="$mean" 'BEGIN { printf "%.3f ms\n", s*1000 }'
    fi
}

section_size() {
    local elf="$1" pattern="$2"
    # `objdump -h` layout:
    #   "Idx Name  Size  VMA  LMA  File off  Algn"
    #   "  0 .text 0000001d 08049000 08049000 00001000  2**0"
    # Sum the Size column (field $3, hex) across every section whose name
    # matches the pattern. e.g. pattern `\.rodata` matches both `.rodata`
    # and `.rodata.__mov_add8_tables`, rolling all per-table sections
    # into one total for the comparison.
    local total=0 hex
    while read -r hex; do
        [ -n "$hex" ] && total=$((total + 16#$hex))
    done < <(objdump -h "$elf" 2>/dev/null \
        | awk -v p="$pattern" 'NF >= 7 && $2 ~ p { print $3 }')
    printf '%d' "$total"
}

# -- pipelines -----------------------------------------------------------

# Run the llvm-mov pipeline on a C source.
# build_llvm_mov <source.c> <out_dir> → writes <out_dir>/elf and <out_dir>/elf.s
build_llvm_mov() {
    local src="$1" out_dir="$2"
    mkdir -p "$out_dir"
    "$CLANG" -m32 -O0 -emit-llvm -S "$src" -o "$out_dir/ir.ll" 2>/dev/null
    # -verify-machineinstrs keeps the bench in lockstep with the test
    # runners: any MIR invariant the legalize breaks gets surfaced
    # at bench time too, before the size/runtime numbers can drift.
    "$LLVM_MOV_LLC" -verify-machineinstrs "$out_dir/ir.ll" \
        -mtriple=mov-unknown-linux-gnu -o "$out_dir/elf.s" 2>/dev/null
    as --32 -o "$out_dir/elf.o" "$out_dir/elf.s" 2>/dev/null
    # Synthesise a minimal _start so the linked binary uses int 0x80 to
    # exit with main's return value, matching the test/Execution harness.
    cat > "$out_dir/_start.s" <<'STARTEOF'
.intel_syntax noprefix
.section .text
.globl _start
_start:
    call main
    mov ebx, eax
    mov eax, 1
    int 0x80
STARTEOF
    as --32 -o "$out_dir/_start.o" "$out_dir/_start.s" 2>/dev/null
    # Link with --gc-sections so unused add-tables are dropped (key for a
    # fair size comparison: the 256 KiB rodata is fixed overhead the
    # linker will discard from any TU that doesn't reference the symbols).
    ld -m elf_i386 -static --gc-sections \
        "$out_dir/_start.o" "$out_dir/elf.o" -o "$out_dir/elf"
}

# Run the movfuscator pipeline on a C source.
# build_movfuscator <source.c> <out_dir> → writes <out_dir>/elf
build_movfuscator() {
    local src="$1" out_dir="$2"
    mkdir -p "$out_dir"
    "$MOVCC" "$src" -o "$out_dir/elf" >"$out_dir/movcc.log" 2>&1
}

# Build the same C source as a "normal" 32-bit native binary at a
# given clang optimisation level. Used as a reference column in the
# bench so the mov-only `.text` / runtime numbers from llvm-mov and
# movfuscator can be compared against what an ordinary compiler
# would have produced from the same source.
#
# Same `_start.s` runtime as the llvm-mov pipeline (`int 0x80` exit,
# no glibc / no dynamic loader), so the only thing differing between
# the columns is the body of `main`. We link with -nostdlib +
# -static + -e _start to get a self-contained ELF for measurement.
build_clang_native() {
    local opt_level="$1" src="$2" out_dir="$3"
    mkdir -p "$out_dir"
    "$CLANG" -m32 "$opt_level" -c "$src" -o "$out_dir/elf.o" 2>/dev/null
    cat > "$out_dir/_start.s" <<'STARTEOF'
.intel_syntax noprefix
.section .text
.globl _start
_start:
    call main
    mov ebx, eax
    mov eax, 1
    int 0x80
STARTEOF
    as --32 -o "$out_dir/_start.o" "$out_dir/_start.s" 2>/dev/null
    ld -m elf_i386 -static --gc-sections \
        "$out_dir/_start.o" "$out_dir/elf.o" -o "$out_dir/elf"
}

# Resolve a `rust_<example>` fixture name to its Cargo metadata.
# Echoes "crate_dir|cargo_name" on success, empty on unknown name.
resolve_rust_fixture() {
    case "$1" in
        rust_main) printf '%s|rust_mov_main' "$LLVM_MOV_DIR/examples/rust/main" ;;
        rust_fib)  printf '%s|rust_mov_fib'  "$LLVM_MOV_DIR/examples/rust/fib"  ;;
        *) printf '' ;;
    esac
}

# Run the llvm-mov pipeline on a Cargo crate (Rust fixture).
# build_llvm_mov_rust <crate_dir> <cargo_name> <out_dir>
#   → writes <out_dir>/elf and <out_dir>/elf.s
build_llvm_mov_rust() {
    local crate_dir="$1" cargo_name="$2" out_dir="$3"
    mkdir -p "$out_dir"
    local triple="i686-unknown-linux-gnu"
    cargo rustc \
        --manifest-path="$crate_dir/Cargo.toml" \
        --release \
        --target="$triple" \
        --quiet \
        -- --emit=llvm-ir,link >/dev/null 2>&1
    local ll
    ll="$(ls -t "$crate_dir/target/$triple/release/deps/${cargo_name}-"*.ll 2>/dev/null | head -1)"
    if [ -z "$ll" ] || ! [ -f "$ll" ]; then
        echo "build_llvm_mov_rust: .ll not found for $cargo_name under $crate_dir/target/$triple/release/deps/" >&2
        return 1
    fi
    "$LLVM_MOV_LLC" -verify-machineinstrs -mtriple=mov-unknown-linux-gnu \
        "$ll" -o "$out_dir/elf.s" 2>/dev/null
    as --32 -o "$out_dir/elf.o" "$out_dir/elf.s" 2>/dev/null
    # Each Rust crate ships its own _start.s pinning the entry symbol
    # (rust_main vs fib_main).
    as --32 -o "$out_dir/_start.o" "$crate_dir/_start.s" 2>/dev/null
    ld -m elf_i386 -static --gc-sections \
        "$out_dir/_start.o" "$out_dir/elf.o" -o "$out_dir/elf"
}

# Build a Cargo crate as a "normal" 32-bit native ELF at a given
# opt-level. Reference column counterpart to build_clang_native for
# C fixtures. We bypass the crate's `[profile.release]` (which pins
# `opt-level = 0` so the IR shapes stay simple for the Mov backend)
# and use `cargo rustc ... -- -C opt-level=N` to override per-build.
# The same hand-written `_start.s` + `int 0x80` exit shape is used,
# so this is comparable to the llvm-mov column of the same crate.
build_rustc_native() {
    local opt_level="$1" crate_dir="$2" cargo_name="$3" out_dir="$4"
    mkdir -p "$out_dir"
    local triple="i686-unknown-linux-gnu"
    cargo rustc \
        --manifest-path="$crate_dir/Cargo.toml" \
        --release \
        --target="$triple" \
        --quiet \
        -- -C opt-level="$opt_level" --emit=link >/dev/null 2>&1
    local lib
    lib="$(ls -t "$crate_dir/target/$triple/release/lib${cargo_name}.a" 2>/dev/null | head -1)"
    if [ -z "$lib" ] || ! [ -f "$lib" ]; then
        return 1
    fi
    as --32 -o "$out_dir/_start.o" "$crate_dir/_start.s" 2>/dev/null
    ld -m elf_i386 -static --gc-sections \
        "$out_dir/_start.o" --whole-archive "$lib" --no-whole-archive \
        -o "$out_dir/elf"
}

# -- main loop -----------------------------------------------------------

RESULTS="${RESULTS_OUT:-$HERE/results.md}"
{
    printf '# bench — llvm-mov vs movfuscator\n\n'
    printf '_Auto-generated by `bench/run.sh`. Each row reports the linked\n'
    printf 'ELF artifact of compiling the same C source through both\n'
    printf 'back-ends. Sizes are in bytes (`stat`/`readelf`); mov ratio is\n'
    printf '`mov-family mnemonic count` / `total mnemonic count` in `.text`._\n\n'
    printf '%s\n\n' "Generated $(date -u +'%Y-%m-%dT%H:%M:%SZ') on $(uname -m) ($(uname -s))."
} > "$RESULTS"

# is_rust_fixture <name> → 0 (yes) or 1 (no)
is_rust_fixture() {
    case "$1" in
        rust_*) return 0 ;;
        *)      return 1 ;;
    esac
}

# Emit the bench-row metrics for a successfully-built llvm-mov ELF.
emit_lm_metrics() {
    local elf="$1" rt="$2"
    printf '| total ELF (bytes) | %s | %s |\n' "$(stat -c %s "$elf")" "$rt"
    printf '| .text size | %s | %s |\n' "$(section_size "$elf" "[.]text")" "$rt"
    printf '| .rodata size | %s | %s |\n' "$(section_size "$elf" "[.]rodata")" "$rt"
    read -r movs tot ratio <<<"$(count_mov_ratio "$elf")"
    printf '| mov count / total | %d / %d (%s) | %s |\n' "$movs" "$tot" "$ratio" "$rt"
    local other
    other="$(non_mov_mnemonics "$elf")"
    printf '| non-mov mnemonics | `%s` | %s |\n' "${other:-(none)}" "$rt"
    local lm_time
    lm_time=$(measure_runtime "$elf")
    printf '| wall-clock runtime (hyperfine mean) | %s | %s |\n' "$lm_time" "$rt"
}

for name in "${FIXTURE_NAMES[@]}"; do
    if is_rust_fixture "$name"; then
        meta="$(resolve_rust_fixture "$name")"
        if [ -z "$meta" ]; then
            echo "warn: unknown rust fixture '$name' (expected one of: ${RUST_FIXTURES[*]})" >&2
            continue
        fi
        crate_dir="${meta%%|*}"
        cargo_name="${meta##*|}"
        if ! [ -d "$crate_dir" ]; then
            echo "warn: rust fixture '$name' crate dir not found at $crate_dir" >&2
            continue
        fi
        echo "$name"

        lm_dir="$WORK/$name/llvm-mov"
        lm_ok=1
        if ! build_llvm_mov_rust "$crate_dir" "$cargo_name" "$lm_dir" \
                2>"$WORK/$name.lm.log"; then
            lm_ok=0
        fi

        # Native rustc reference per opt level — counterpart to the
        # clang -O0..-O3 columns for C fixtures.
        declare -A r_dir r_ok
        for lvl in 0 1 2 3; do
            r_dir[$lvl]="$WORK/$name/rustc-O$lvl"
            r_ok[$lvl]=1
            if ! build_rustc_native "$lvl" "$crate_dir" "$cargo_name" \
                    "${r_dir[$lvl]}" 2>"$WORK/$name.rustc-O$lvl.log"; then
                r_ok[$lvl]=0
            fi
        done

        # Per-cell formatter helpers (same as the C branch's).
        size_cell() {  # $1=ok, $2=elf
            if [ "$1" -eq 1 ]; then printf '%s' "$(stat -c %s "$2")"; else printf '—'; fi
        }
        sec_cell() {
            if [ "$1" -eq 1 ]; then printf '%s' "$(section_size "$2" "$3")"; else printf '—'; fi
        }
        mov_cell() {
            if [ "$1" -eq 1 ]; then
                read -r m t r <<<"$(count_mov_ratio "$2")"
                printf '%d / %d (%s)' "$m" "$t" "$r"
            else printf '—'; fi
        }
        nonmov_cell() {
            if [ "$1" -eq 1 ]; then printf '`%s`' "$(non_mov_mnemonics "$2" || printf '(none)')"; else printf '—'; fi
        }
        rt_cell() {
            if [ "$1" -eq 1 ]; then printf '%s' "$(measure_runtime "$2")"; else printf '—'; fi
        }

        {
            printf '## %s\n\n' "$name"
            printf '```rust\n%s\n```\n\n' "$(cat "$crate_dir/src/lib.rs")"
            printf '| metric | llvm-mov (Rust) | movfuscator | rustc -O0 | rustc -O1 | rustc -O2 | rustc -O3 |\n'
            printf '|---|---:|---:|---:|---:|---:|---:|\n'

            # `—` (em dash) in the movfuscator column flags "not
            # applicable: movcc is a C-only frontend".
            printf '| total ELF (bytes) | %s | — | %s | %s | %s | %s |\n' \
                "$(size_cell $lm_ok "$lm_dir/elf")" \
                "$(size_cell ${r_ok[0]} "${r_dir[0]}/elf")" \
                "$(size_cell ${r_ok[1]} "${r_dir[1]}/elf")" \
                "$(size_cell ${r_ok[2]} "${r_dir[2]}/elf")" \
                "$(size_cell ${r_ok[3]} "${r_dir[3]}/elf")"

            printf '| .text size | %s | — | %s | %s | %s | %s |\n' \
                "$(sec_cell $lm_ok "$lm_dir/elf" "[.]text")" \
                "$(sec_cell ${r_ok[0]} "${r_dir[0]}/elf" "[.]text")" \
                "$(sec_cell ${r_ok[1]} "${r_dir[1]}/elf" "[.]text")" \
                "$(sec_cell ${r_ok[2]} "${r_dir[2]}/elf" "[.]text")" \
                "$(sec_cell ${r_ok[3]} "${r_dir[3]}/elf" "[.]text")"

            printf '| .rodata size | %s | — | %s | %s | %s | %s |\n' \
                "$(sec_cell $lm_ok "$lm_dir/elf" "[.]rodata")" \
                "$(sec_cell ${r_ok[0]} "${r_dir[0]}/elf" "[.]rodata")" \
                "$(sec_cell ${r_ok[1]} "${r_dir[1]}/elf" "[.]rodata")" \
                "$(sec_cell ${r_ok[2]} "${r_dir[2]}/elf" "[.]rodata")" \
                "$(sec_cell ${r_ok[3]} "${r_dir[3]}/elf" "[.]rodata")"

            printf '| mov count / total | %s | — | %s | %s | %s | %s |\n' \
                "$(mov_cell $lm_ok "$lm_dir/elf")" \
                "$(mov_cell ${r_ok[0]} "${r_dir[0]}/elf")" \
                "$(mov_cell ${r_ok[1]} "${r_dir[1]}/elf")" \
                "$(mov_cell ${r_ok[2]} "${r_dir[2]}/elf")" \
                "$(mov_cell ${r_ok[3]} "${r_dir[3]}/elf")"

            printf '| non-mov mnemonics | %s | — | %s | %s | %s | %s |\n' \
                "$(nonmov_cell $lm_ok "$lm_dir/elf")" \
                "$(nonmov_cell ${r_ok[0]} "${r_dir[0]}/elf")" \
                "$(nonmov_cell ${r_ok[1]} "${r_dir[1]}/elf")" \
                "$(nonmov_cell ${r_ok[2]} "${r_dir[2]}/elf")" \
                "$(nonmov_cell ${r_ok[3]} "${r_dir[3]}/elf")"

            printf '| wall-clock runtime (hyperfine mean) | %s | — | %s | %s | %s | %s |\n' \
                "$(rt_cell $lm_ok "$lm_dir/elf")" \
                "$(rt_cell ${r_ok[0]} "${r_dir[0]}/elf")" \
                "$(rt_cell ${r_ok[1]} "${r_dir[1]}/elf")" \
                "$(rt_cell ${r_ok[2]} "${r_dir[2]}/elf")" \
                "$(rt_cell ${r_ok[3]} "${r_dir[3]}/elf")"

            printf '\n'
        } >> "$RESULTS"
        unset r_dir r_ok
        continue
    fi

    src="$(resolve_fixture "$name")"
    if [ -z "$src" ]; then
        echo "warn: fixture '$name.c' not found in any of:" >&2
        for dir in "${FIXTURE_DIRS[@]}"; do
            echo "  $dir" >&2
        done
        continue
    fi
    echo "$name"

    lm_dir="$WORK/$name/llvm-mov"
    mf_dir="$WORK/$name/movfuscator"

    lm_ok=1
    if ! build_llvm_mov "$src" "$lm_dir" 2>"$WORK/$name.lm.log"; then
        lm_ok=0
    fi
    mf_ok=1
    if ! build_movfuscator "$src" "$mf_dir" 2>"$WORK/$name.mf.log"; then
        mf_ok=0
    fi

    # Clang native reference build per optimisation level. The
    # `_start`/`int 0x80` runtime is the same as the llvm-mov pipeline,
    # so the only thing differing between these columns and the
    # mov-only columns is what `main`'s body looks like.
    declare -A c_dir c_ok
    for lvl in O0 O1 O2 O3; do
        c_dir[$lvl]="$WORK/$name/clang-$lvl"
        c_ok[$lvl]=1
        if ! build_clang_native "-$lvl" "$src" "${c_dir[$lvl]}" \
                2>"$WORK/$name.clang-$lvl.log"; then
            c_ok[$lvl]=0
        fi
    done

    {
        printf '## %s\n\n' "$name"
        printf '```c\n%s\n```\n\n' "$(cat "$src")"
        printf '| metric | llvm-mov | movfuscator | clang -O0 | clang -O1 | clang -O2 | clang -O3 |\n'
        printf '|---|---:|---:|---:|---:|---:|---:|\n'

        # Helper closures for per-cell formatting. `cell <ok> <elf> <kind>`
        # echoes the right thing for the column.
        size_cell() {  # $1=ok, $2=elf
            if [ "$1" -eq 1 ]; then printf '%s' "$(stat -c %s "$2")"; else printf '—'; fi
        }
        sec_cell() {   # $1=ok, $2=elf, $3=section regex
            if [ "$1" -eq 1 ]; then printf '%s' "$(section_size "$2" "$3")"; else printf '—'; fi
        }
        mov_cell() {   # $1=ok, $2=elf
            if [ "$1" -eq 1 ]; then
                read -r m t r <<<"$(count_mov_ratio "$2")"
                printf '%d / %d (%s)' "$m" "$t" "$r"
            else printf '—'; fi
        }
        nonmov_cell() {  # $1=ok, $2=elf
            if [ "$1" -eq 1 ]; then printf '`%s`' "$(non_mov_mnemonics "$2" || printf '(none)')"; else printf '—'; fi
        }
        rt_cell() {    # $1=ok, $2=elf
            if [ "$1" -eq 1 ]; then printf '%s' "$(measure_runtime "$2")"; else printf '—'; fi
        }

        printf '| total ELF (bytes) | %s | %s | %s | %s | %s | %s |\n' \
            "$(size_cell $lm_ok "$lm_dir/elf")" \
            "$(size_cell $mf_ok "$mf_dir/elf")" \
            "$(size_cell ${c_ok[O0]} "${c_dir[O0]}/elf")" \
            "$(size_cell ${c_ok[O1]} "${c_dir[O1]}/elf")" \
            "$(size_cell ${c_ok[O2]} "${c_dir[O2]}/elf")" \
            "$(size_cell ${c_ok[O3]} "${c_dir[O3]}/elf")"

        printf '| .text size | %s | %s | %s | %s | %s | %s |\n' \
            "$(sec_cell $lm_ok "$lm_dir/elf" "[.]text")" \
            "$(sec_cell $mf_ok "$mf_dir/elf" "[.]text")" \
            "$(sec_cell ${c_ok[O0]} "${c_dir[O0]}/elf" "[.]text")" \
            "$(sec_cell ${c_ok[O1]} "${c_dir[O1]}/elf" "[.]text")" \
            "$(sec_cell ${c_ok[O2]} "${c_dir[O2]}/elf" "[.]text")" \
            "$(sec_cell ${c_ok[O3]} "${c_dir[O3]}/elf" "[.]text")"

        printf '| .rodata size | %s | %s | %s | %s | %s | %s |\n' \
            "$(sec_cell $lm_ok "$lm_dir/elf" "[.]rodata")" \
            "$(sec_cell $mf_ok "$mf_dir/elf" "[.]rodata")" \
            "$(sec_cell ${c_ok[O0]} "${c_dir[O0]}/elf" "[.]rodata")" \
            "$(sec_cell ${c_ok[O1]} "${c_dir[O1]}/elf" "[.]rodata")" \
            "$(sec_cell ${c_ok[O2]} "${c_dir[O2]}/elf" "[.]rodata")" \
            "$(sec_cell ${c_ok[O3]} "${c_dir[O3]}/elf" "[.]rodata")"

        printf '| mov count / total | %s | %s | %s | %s | %s | %s |\n' \
            "$(mov_cell $lm_ok "$lm_dir/elf")" \
            "$(mov_cell $mf_ok "$mf_dir/elf")" \
            "$(mov_cell ${c_ok[O0]} "${c_dir[O0]}/elf")" \
            "$(mov_cell ${c_ok[O1]} "${c_dir[O1]}/elf")" \
            "$(mov_cell ${c_ok[O2]} "${c_dir[O2]}/elf")" \
            "$(mov_cell ${c_ok[O3]} "${c_dir[O3]}/elf")"

        printf '| non-mov mnemonics | %s | %s | %s | %s | %s | %s |\n' \
            "$(nonmov_cell $lm_ok "$lm_dir/elf")" \
            "$(nonmov_cell $mf_ok "$mf_dir/elf")" \
            "$(nonmov_cell ${c_ok[O0]} "${c_dir[O0]}/elf")" \
            "$(nonmov_cell ${c_ok[O1]} "${c_dir[O1]}/elf")" \
            "$(nonmov_cell ${c_ok[O2]} "${c_dir[O2]}/elf")" \
            "$(nonmov_cell ${c_ok[O3]} "${c_dir[O3]}/elf")"

        printf '| wall-clock runtime (hyperfine mean) | %s | %s | %s | %s | %s | %s |\n' \
            "$(rt_cell $lm_ok "$lm_dir/elf")" \
            "$(rt_cell $mf_ok "$mf_dir/elf")" \
            "$(rt_cell ${c_ok[O0]} "${c_dir[O0]}/elf")" \
            "$(rt_cell ${c_ok[O1]} "${c_dir[O1]}/elf")" \
            "$(rt_cell ${c_ok[O2]} "${c_dir[O2]}/elf")" \
            "$(rt_cell ${c_ok[O3]} "${c_dir[O3]}/elf")"

        printf '\n'
    } >> "$RESULTS"
    unset c_dir c_ok
done

echo
echo "wrote: $RESULTS"
