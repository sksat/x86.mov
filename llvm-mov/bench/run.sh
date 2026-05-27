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
FIXTURES="$MOVFUSCATOR_WASM/tests/fixtures"

BUILD_DIR="${BUILD_DIR:-$LLVM_MOV_DIR/build}"
LLVM_MOV_LLC="$BUILD_DIR/bin/llvm-mov-llc"
MOVCC="$MOVFUSCATOR_WASM/vendor/movfuscator/build/movcc"

CLANG="${CLANG:-clang-22}"

# -- fixture selection ---------------------------------------------------

# Default set: single-file fixtures that both pipelines build end-to-end
# from $FIXTURES/<name>.c. `sum10` is the most interesting comparison —
# arithmetic-only would compress to a constant in clang's optimiser
# (LLVM constant folds the whole sum), so the loop keeps the addition
# alive across all 4 32-bit byte stages, exercising the ADD legalize
# tables. `return0`/`return42` show the trivial floor.
DEFAULT_FIXTURES=(
    return0
    return42
    sum10
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

RESULTS="$HERE/results.md"
{
    printf '# bench — llvm-mov vs movfuscator\n\n'
    printf '_Auto-generated by `bench/run.sh`. Each row reports the linked\n'
    printf 'ELF artifact of compiling the same C source through both\n'
    printf 'back-ends. Sizes are in bytes (`stat`/`readelf`); mov ratio is\n'
    printf '`mov-family mnemonic count` / `total mnemonic count` in `.text`._\n\n'
    printf '%s\n\n' "Generated $(date -u +'%Y-%m-%dT%H:%M:%SZ') on $(uname -m) ($(uname -s))."
} > "$RESULTS"

for name in "${FIXTURE_NAMES[@]}"; do
    src="$FIXTURES/$name.c"
    if [ ! -f "$src" ]; then
        echo "warn: fixture $src not found, skipping" >&2
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

            lm_text=$(section_size "$lm_elf" "\\.text")
            mf_text=$(section_size "$mf_elf" "\\.text")
            printf '| .text size | %s | %s |\n' "${lm_text:-0}" "${mf_text:-0}"

            lm_rodata=$(section_size "$lm_elf" "\\.rodata")
            mf_rodata=$(section_size "$mf_elf" "\\.rodata")
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
        else
            [ "$lm_ok" -eq 0 ] && printf '| (llvm-mov build failed; see log) |||\n'
            [ "$mf_ok" -eq 0 ] && printf '| (movfuscator build failed; see log) |||\n'
        fi
        printf '\n'
    } >> "$RESULTS"
done

echo
echo "wrote: $RESULTS"
