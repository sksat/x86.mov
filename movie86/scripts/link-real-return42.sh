#!/usr/bin/env bash
# Statically link the committed return42.o against the movfuscator
# runtime (crt0.o + crtf.o + crtd.o + softfloat32.o) plus a minimal
# stubs.s that provides sigaction (no-op) and exit (cdecl).
#
# Reproduces the real-movfuscator-binary E2E demo for movie86.
# Output: /tmp/movie86-link/return42-real.elf
#
# **Note on exit code:** movfuscator's crt0 emits `push("$0");
# jmp_extern("exit");` — it HARDCODES exit(0) regardless of main's
# return value. So this binary exits 0, not 42, even though the C
# source says `return 42`. That's a movfuscator quirk, not an emulator
# bug. Verified by running the dynamically-linked version natively:
# also exits with 0-ish (1 actually, an artifact of the dynamic linker).
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
   exit       — Linux i386 SYS_exit(status). cdecl convention:
              movfuscator's jmp_extern pushes (args..., retaddr), so
              [esp+0]=retaddr, [esp+4]=arg1. */

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
EOF

as --32 stubs.s -o stubs.o

/usr/bin/ld -m elf_i386 -static --hash-style=gnu \
    "$B/crt0.o" "$O" "$B/crtf.o" "$B/crtd.o" "$SF/softfloat32.o" stubs.o \
    -o "$OUT/return42-real.elf"

echo "linked: $OUT/return42-real.elf ($(stat -c %s "$OUT/return42-real.elf") bytes)"
echo "run with: cargo run --release --bin movie86 -- $OUT/return42-real.elf"
echo "(exits with 0 — see header comment in this script)"
