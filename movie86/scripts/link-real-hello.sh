#!/usr/bin/env bash
# Statically link the committed hello.o (= movfuscator-built "Hello\n"
# program) against the movfuscator runtime + a minimal printf stub.
# Output: /tmp/movie86-link/hello-real.elf
#
# Demonstrates that movie86 can drive a movfuscator-built program with
# libc syscalls beyond just exit — here printf goes through the
# dispatch trampoline and writes to stdout.
#
# **printf stub is fixture-specific:** it hardcodes a 6-byte write
# because a real strlen-based printf needs cmp+jcc + EFLAGS modeling,
# which is outside movie86's mov-only scope. Sufficient for the
# committed "Hello\n" fixture (exactly 6 bytes); won't work for other
# format strings.
#
# Same vendor prereqs as link-real-return42.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GITDIR="$(cd "$ROOT" && git rev-parse --git-common-dir)"
REPO="$(cd "$GITDIR/.." && pwd)"

B="$REPO/movfuscator-wasm/vendor/movfuscator/build"
SF="$REPO/movfuscator-wasm/vendor/movfuscator/movfuscator/lib"
HELLO="$REPO/movfuscator-wasm/tests/goldens-o/hello.o"

for f in "$B/crt0.o" "$B/crtf.o" "$B/crtd.o" "$SF/softfloat32.o" "$HELLO"; do
    if [ ! -f "$f" ]; then
        echo "FAIL: $f missing" >&2
        echo "      cd movfuscator-wasm && make setup && make build-native" >&2
        exit 1
    fi
done

OUT="${OUT:-/tmp/movie86-link}"
mkdir -p "$OUT"
cd "$OUT"

cat > stubs-hello.s <<'EOF'
/* cdecl stubs for hello.c through movie86.
   movfuscator's jmp_extern follows cdecl: [esp+0]=retaddr, [esp+4]=arg.
   printf hardcodes length 6 (= "Hello\n") because a real strlen
   needs cmp+jcc — outside movie86's mov-only scope. */

.text

.globl sigaction
.type sigaction, @function
sigaction:
    movl $0, %eax
    ret

.globl exit
.type exit, @function
exit:
    movl $1, %eax
    movl 4(%esp), %ebx
    int  $0x80

.globl printf
.type printf, @function
printf:
    movl $4, %eax              /* SYS_write */
    movl $1, %ebx              /* stdout */
    movl 4(%esp), %ecx         /* buf = fmt */
    movl $6, %edx              /* hardcoded length: "Hello\n" */
    int  $0x80
    ret
EOF

as --32 stubs-hello.s -o stubs-hello.o

/usr/bin/ld -m elf_i386 -static --hash-style=gnu \
    "$B/crt0.o" "$HELLO" "$B/crtf.o" "$B/crtd.o" "$SF/softfloat32.o" stubs-hello.o \
    -o "$OUT/hello-real.elf"

echo "linked: $OUT/hello-real.elf ($(stat -c %s "$OUT/hello-real.elf") bytes)"
echo "run with: cargo run --release --bin movie86 -- $OUT/hello-real.elf"
echo "(should print 'Hello' to stdout and exit 0)"
