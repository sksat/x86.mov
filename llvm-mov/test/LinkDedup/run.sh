#!/usr/bin/env bash
# Link-time gate: the stage-7 byte tables must appear **once** in a linked
# binary, no matter how many objects went into it.
#
# Every object this backend emits carries the full set of lookup tables the
# mov-only legalize indexes — ~860 KiB of them. That is fine for the
# single-translation-unit fixtures the rest of the suite builds, and it is
# the dominant cost the moment anything real gets linked: lcc's 32 objects
# came to 55 MB of which ~27 MB was copies of the same tables. Nothing in
# the other gates notices, because they all link exactly one object.
#
# So this one links several and checks the section sizes directly.

set -euo pipefail

BUILD_DIR="${1:-build}"
DRIVER="${BUILD_DIR}/bin/llvm-mov-llc"
HERE="$(cd "$(dirname "$0")" && pwd)"

if ! [ -x "$DRIVER" ]; then
    echo "error: $DRIVER not found — build first ('make build')." 1>&2
    exit 2
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Four objects that each use the tables (any arithmetic does), with distinct
# symbol names so they can be linked together.
for i in 0 1 2 3; do
    cat > "$WORK/m$i.ll" <<EOF
target triple = "mov-unknown-linux-gnu"
define i32 @f$i(i32 %a, i32 %b) {
  %s = add i32 %a, %b
  %t = xor i32 %s, $i
  ret i32 %t
}
EOF
    "$DRIVER" "$WORK/m$i.ll" -o "$WORK/m$i.s"
    as --32 -o "$WORK/m$i.o" "$WORK/m$i.s"
done

cat > "$WORK/_start.s" <<'EOF'
.intel_syntax noprefix
.section .text
.global _start
_start:
    push 1
    push 2
    call f0
    add esp, 8
    mov ebx, eax
    mov eax, 1
    int 0x80
EOF
as --32 -o "$WORK/_start.o" "$WORK/_start.s"
ld -m elf_i386 -static -e _start -o "$WORK/multi.elf" \
   "$WORK/_start.o" "$WORK/m0.o" "$WORK/m1.o" "$WORK/m2.o" "$WORK/m3.o"

# One object's worth of tables, measured from a single object file.
one=$(size -A "$WORK/m0.o" | awk '/^\.rodata\.__mov_/ {s+=$2} END {print s+0}')
# What the four-object link actually kept.
all=$(size -A "$WORK/multi.elf" | awk '/^\.rodata/ {s+=$2} END {print s+0}')

if [ "$one" = 0 ]; then
    echo "FAIL  no __mov_ tables found in a single object — has the naming changed?" 1>&2
    exit 1
fi

# Allow a little slack for alignment padding and any non-table .rodata the
# linker merged in; the failure mode we care about is a multiple of `one`.
limit=$(( one + one / 4 ))
printf 'one object: %s bytes of tables\n' "$one"
printf '4-object link: %s bytes of .rodata (budget %s)\n' "$all" "$limit"

if [ "$all" -gt "$limit" ]; then
    echo "FAIL  tables were duplicated: $all bytes for what should be ~$one" 1>&2
    echo "      (each object carries its own copy; they need to be COMDAT)" 1>&2
    exit 1
fi

# The binary must still run — dedup that drops a table the code references
# would be worse than duplication.
set +e
"$WORK/multi.elf"
got=$?
set -e
if [ "$got" != 3 ]; then
    echo "FAIL  linked binary returned $got, expected 3 (2 + 1 xor 0)" 1>&2
    exit 1
fi

echo "PASS  tables shared across objects, linked binary runs"
