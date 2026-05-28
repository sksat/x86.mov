#!/usr/bin/env bash
# bench/run.sh — side-by-side comparison of llvm-mov-llc vs movfuscator.
#
# Both back-ends consume the *same* C source from
# movfuscator-wasm/tests/fixtures/ and produce x86-32 ELF. We measure:
#
#   - total ELF size                 (`stat -c %s`)
#   - .text section size             (`size --format=sysv`)
#   - .rodata section size           (--gc-sections drops llvm-mov's add
#                                     tables when unused, so the data
#                                     overhead is fixture-dependent)
#   - mov ratio                      (mov mnemonics / total instructions in
#                                     .text — 1.0 = fully mov-only)
#   - non-mov mnemonic counts        (which opcodes are still in the .text)
#
# llvm-mov pipeline:
#   clang -m32 -emit-llvm -S → llvm-mov-llc -mtriple=mov-... → as --32 → ld
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
DEFAULT_FIXTURES=(
    return0
    return42
    eq42
    lt_unsigned
    bitops
    sum10
    fib10
    shifts
    fib_rec
    multi_call
)

if [ $# -gt 0 ]; then
    FIXTURE_NAMES=("$@")
else
    FIXTURE_NAMES=("${DEFAULT_FIXTURES[@]}")
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
    "$LLVM_MOV_LLC" "$out_dir/ir.ll" -mtriple=mov-unknown-linux-gnu \
        -o "$out_dir/elf.s" 2>/dev/null
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

for name in "${FIXTURE_NAMES[@]}"; do
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

    {
        printf '## %s\n\n' "$name"
        printf '```c\n%s\n```\n\n' "$(cat "$src")"
        printf '| metric | llvm-mov | movfuscator |\n'
        printf '|---|---:|---:|\n'

        if [ "$lm_ok" -eq 1 ] && [ "$mf_ok" -eq 1 ]; then
            lm_elf="$lm_dir/elf"
            mf_elf="$mf_dir/elf"

            lm_total=$(stat -c %s "$lm_elf")
            mf_total=$(stat -c %s "$mf_elf")
            printf '| total ELF (bytes) | %s | %s |\n' \
                "$(printf '%d' "$lm_total")" "$(printf '%d' "$mf_total")"

            # Patterns use `[.]` for the leading literal dot rather than
            # `\.` to keep mawk/gawk quiet (gawk warns "escape sequence
            # \. treated as plain ." for the latter shape).
            lm_text=$(section_size "$lm_elf" "[.]text")
            mf_text=$(section_size "$mf_elf" "[.]text")
            printf '| .text size | %s | %s |\n' "${lm_text:-0}" "${mf_text:-0}"

            lm_rodata=$(section_size "$lm_elf" "[.]rodata")
            mf_rodata=$(section_size "$mf_elf" "[.]rodata")
            printf '| .rodata size | %s | %s |\n' "${lm_rodata:-0}" "${mf_rodata:-0}"

            read -r lm_movs lm_tot lm_ratio <<<"$(count_mov_ratio "$lm_elf")"
            read -r mf_movs mf_tot mf_ratio <<<"$(count_mov_ratio "$mf_elf")"
            printf '| mov count / total | %d / %d (%s) | %d / %d (%s) |\n' \
                "$lm_movs" "$lm_tot" "$lm_ratio" \
                "$mf_movs" "$mf_tot" "$mf_ratio"

            lm_other=$(non_mov_mnemonics "$lm_elf")
            mf_other=$(non_mov_mnemonics "$mf_elf")
            printf '| non-mov mnemonics | `%s` | `%s` |\n' \
                "${lm_other:-(none)}" "${mf_other:-(none)}"

            lm_time=$(measure_runtime "$lm_elf")
            mf_time=$(measure_runtime "$mf_elf")
            printf '| wall-clock runtime (hyperfine mean) | %s | %s |\n' \
                "$lm_time" "$mf_time"
        else
            [ "$lm_ok" -eq 0 ] && printf '| (llvm-mov build failed; see log) |||\n'
            [ "$mf_ok" -eq 0 ] && printf '| (movfuscator build failed; see log) |||\n'
        fi
        printf '\n'
    } >> "$RESULTS"
done

echo
echo "wrote: $RESULTS"
