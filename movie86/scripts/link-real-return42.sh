#!/usr/bin/env bash
# Statically link the committed return42.o against the movfuscator
# runtime (crt0.o + crtf.o + crtd.o + softfloat32.o) plus a tiny
# stubs.s that provides sigaction (no-op) and exit (reads from
# movfuscator's jmp_r0 — the runtime's libc-call argument slot).
#
# Reproduces the real-movfuscator-binary E2E demo for movie86.
# Output: /tmp/movie86-link/return42-real.elf
#
# Prereqs (gitignored, materialized by movfuscator-wasm/Makefile):
#   movfuscator-wasm/vendor/movfuscator/build/crt0.o + crtf.o + crtd.o
#   movfuscator-wasm/vendor/movfuscator/movfuscator/lib/softfloat32.o
# If they're missing:
#   cd movfuscator-wasm && make setup && make build-native

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# vendor/ is gitignored and only materialized in the *main* checkout of
# movfuscator-wasm — not in each git worktree. So `git rev-parse
# --show-toplevel` gives our worktree dir, but we want the original
# repo's vendor. Resolve via git common-dir.
GITDIR="$(cd "$ROOT" && git rev-parse --git-common-dir)"
REPO="$(cd "$GITDIR/.." && pwd)"

B="$REPO/movfuscator-wasm/vendor/movfuscator/build"
SF="$REPO/movfuscator-wasm/vendor/movfuscator/movfuscator/lib"
O="$REPO/movfuscator-wasm/tests/goldens-o/return42.o"

for f in "$B/crt0.o" "$B/crtf.o" "$B/crtd.o" "$SF/softfloat32.o" "$O"; do
    if [ ! -f "$f" ]; then
        echo "FAIL: $f missing" >&2
        echo "      cd movfuscator-wasm && make setup && make build-native" >&2
        exit 1
    fi
done

OUT="${OUT:-/tmp/movie86-link}"
mkdir -p "$OUT"
cd "$OUT"

cat > stubs.s <<'EOF'
/* Minimal libc replacements for the movfuscator runtime.
   sigaction — return 0 success without installing a real handler.
              (Not needed: movie86 wires SIGSEGV → dispatch / SIGILL →
              master_loop directly from the ELF symbol table.)
   exit       — Linux i386 SYS_exit(status). movfuscator's libc-call
              convention places the arg in jmp_r0, NOT on the cdecl
              stack. ld resolves the external reference to wherever
              the linked runtime put jmp_r0. */

.text

.globl sigaction
.type sigaction, @function
sigaction:
    movl $0, %eax
    ret

.extern jmp_r0

.globl exit
.type exit, @function
exit:
    movl $1, %eax
    movl jmp_r0, %ebx
    int  $0x80
EOF

as --32 stubs.s -o stubs.o

/usr/bin/ld -m elf_i386 -static --hash-style=gnu \
    "$B/crt0.o" "$O" "$B/crtf.o" "$B/crtd.o" "$SF/softfloat32.o" stubs.o \
    -o "$OUT/return42-real.elf"

echo "linked: $OUT/return42-real.elf ($(stat -c %s "$OUT/return42-real.elf") bytes)"
echo "run with: cargo run --release --bin movie86 -- $OUT/return42-real.elf"
