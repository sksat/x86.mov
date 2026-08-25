#!/usr/bin/env bash
# Deterministic code-generation cost metrics for mov-only fixtures.
#
# Unlike wall-clock timing of tiny ELF processes, these numbers do not include
# exec/syscall noise.  They are intended for before/after compiler diffs:
#   --update  regenerate bench/codegen-results.md
#   --check   fail when current codegen differs from the committed results

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
DRIVER="$BUILD_DIR/bin/llvm-mov-llc"
RESULTS="$HERE/codegen-results.md"
MODE="${1:-print}"

if ! [ -x "$DRIVER" ]; then
    echo "error: $DRIVER not found; run 'make build' first" >&2
    exit 2
fi
if [ "$MODE" != print ] && [ "$MODE" != --update ] && [ "$MODE" != --check ]; then
    echo "usage: $0 [--update|--check]" >&2
    exit 2
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
REPORT="$WORK/results.md"

{
    echo '# llvm-mov deterministic codegen metrics'
    echo
    echo 'Generated from every `test/MovOnly/*.ll` fixture. Lower is better for all numeric columns.'
    echo
    echo '| fixture | .text bytes | mov instructions | memory loads | memory stores | table loads | high-byte index ops |'
    echo '|---|---:|---:|---:|---:|---:|---:|'
} > "$REPORT"

total_bytes=0 total_mov=0 total_load=0 total_store=0 total_table=0 total_high=0
shopt -s nullglob
fixtures=("$ROOT"/test/MovOnly/*.ll)
for ll in "${fixtures[@]}"; do
    name="$(basename "$ll" .ll)"
    asm="$WORK/$name.s"
    obj="$WORK/$name.o"
    "$DRIVER" -verify-machineinstrs "$ll" -o "$asm"
    as --32 -o "$obj" "$asm"

    bytes="$(size --format=sysv "$obj" | awk '$1==".text" {print $2}')"
    # Classify the canonical Intel-syntax text emitted by this backend.
    movs="$(awk '/^[[:space:]]*mov[[:space:]]/ {n++} END {print n+0}' "$asm")"
    loads="$(awk '/^[[:space:]]*mov[[:space:]]/ && /,[[:space:]]*(byte|dword) ptr \[/ {n++} END {print n+0}' "$asm")"
    stores="$(awk '/^[[:space:]]*mov[[:space:]]+(byte|dword) ptr \[/ {n++} END {print n+0}' "$asm")"
    tables="$(awk '/^[[:space:]]*mov[[:space:]]/ && /\[__mov_[^]]+ \+ [a-z]+\]/ {n++} END {print n+0}' "$asm")"
    high="$(awk '/^[[:space:]]*mov[[:space:]]+(ah|bh|ch|dh),/ {n++} END {print n+0}' "$asm")"

    printf '| %s | %d | %d | %d | %d | %d | %d |\n' \
        "$name" "$bytes" "$movs" "$loads" "$stores" "$tables" "$high" >> "$REPORT"
    total_bytes=$((total_bytes + bytes))
    total_mov=$((total_mov + movs))
    total_load=$((total_load + loads))
    total_store=$((total_store + stores))
    total_table=$((total_table + tables))
    total_high=$((total_high + high))
done
printf '| **TOTAL** | **%d** | **%d** | **%d** | **%d** | **%d** | **%d** |\n' \
    "$total_bytes" "$total_mov" "$total_load" "$total_store" "$total_table" "$total_high" >> "$REPORT"

case "$MODE" in
    --update)
        cp "$REPORT" "$RESULTS"
        echo "updated $RESULTS"
        ;;
    --check)
        if ! diff -u "$RESULTS" "$REPORT"; then
            echo "codegen metrics changed; inspect the diff and run 'make codegen-metrics-update' if intentional" >&2
            exit 1
        fi
        echo 'codegen metrics match committed results'
        ;;
    print)
        cat "$REPORT"
        ;;
esac
