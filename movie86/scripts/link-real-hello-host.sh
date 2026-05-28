#!/usr/bin/env bash
# Statically link the committed `hello.o` (= movfuscator-built
# "Hello\n" program) against the mov-loop CRT + the **host-wrapper**
# sentinel stubs.
#
# Output: /tmp/movie86-link/hello-host.elf
#
# This replaces the hardcoded-6-byte cdecl printf stub used by
# `link-real-hello.sh`. Instead of a real `int 0x80` syscall, the
# `printf` / `exit` / `sigaction` stubs each consist of:
#
#     int $0x81    ; CD 81 — trap to movie86's LibcHost
#     ret          ; C3    — pop the cdecl retaddr
#
# At load time `StdHost::scan_libc_stubs` walks the ELF .symtab, sees
# the `CD 81` sentinel at &printf / &exit / &sigaction, and registers
# the wrappers. The host-side printf then parses the format string
# (a `%s`/`%d`/`%c`/`%%` subset) without needing cmp/jcc/EFLAGS in the
# emulator core. The same fixture would also run under a future
# wasm-based movie86 host with no link-script changes.
#
# Same vendor prereqs as `link-real-hello.sh`.

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

cat > stubs-host.s <<'EOF'
/* Host-wrapper sentinel stubs for hello.c through movie86.
   Each function is `int $0x81; ret` — movie86 traps on int 0x81,
   dispatches to a host LibcHost implementation that reads cdecl
   args from [esp+4..] and does the work. The guest's `ret` (after
   the host call returns) pops the cdecl retaddr normally.

   Unlike the previous fixture-specific cdecl stubs, these stubs are
   uniform across all wrapped functions — the host's symbol-table
   sweep (StdHost::scan_libc_stubs) picks them up by name. */

.text

.globl sigaction
.type sigaction, @function
sigaction:
    int  $0x81
    ret

.globl exit
.type exit, @function
exit:
    int  $0x81
    ret

.globl printf
.type printf, @function
printf:
    int  $0x81
    ret
EOF

as --32 stubs-host.s -o stubs-host.o

/usr/bin/ld -m elf_i386 -static --hash-style=gnu \
    "$B/crt0.o" "$HELLO" "$B/crtf.o" "$B/crtd.o" "$SF/softfloat32.o" stubs-host.o \
    -o "$OUT/hello-host.elf"

echo "linked: $OUT/hello-host.elf ($(stat -c %s "$OUT/hello-host.elf") bytes)"
echo "run with: cargo run --release --bin movie86 -- $OUT/hello-host.elf"
echo "(should print 'Hello' to stdout via the host-side printf wrapper and exit 0)"
