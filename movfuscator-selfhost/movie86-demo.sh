#!/usr/bin/env bash
# movie86 end-to-end demo for the self-host toolchain.
#
# Proves the *live* mov pipeline (the same cpp/rcc/as that the self-host survey
# drives) produces a binary the movie86 emulator actually executes:
#
#   prog.c ─cpp→ .i ─rcc -target=x86/mov→ .s ─as→ .o ─ld -static→ mov-only ELF
#         → run under ../movie86
#
# This is the execution substrate that self-host milestone 3 (run the
# self-hosted rcc) will stand on. Until the full rcc links (blocked on wall #3,
# see CLAUDE.md / run.sh), this stands in as the "mov output runs in movie86"
# check with a small program.
#
# NB: movfuscator's crt0 hardcodes exit(0), so the process exit code does NOT
# reflect main()'s return value — a clean exit 0 means "ran to completion
# without faulting", which is the property we care about here.

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
wasm="$here/../movfuscator-wasm"
movie86_dir="$here/../movie86"
B="$wasm/vendor/movfuscator/build"
SF="$wasm/vendor/movfuscator/movfuscator/lib"

for f in "$wasm/build/cpp.js" "$wasm/build/rcc.js" "$wasm/build/as.js" \
         "$B/crt0.o" "$B/crtf.o" "$B/crtd.o" "$SF/softfloat32.o"; do
    if [ ! -e "$f" ]; then
        echo "FAIL: $f missing — set up the sibling toolchain:" >&2
        echo "  (cd $wasm && make setup build-wasm build-wasm-as build-native)" >&2
        exit 1
    fi
done

out="${OUT:-/tmp/movfuscator-selfhost-movie86}"
mkdir -p "$out"; cd "$out"

cat > prog.c <<'EOF'
int main(void) { int a = 6, b = 7; return a * b; }
EOF

echo "== live mov pipeline =="
node "$wasm/build/cpp.js" \
    -U__GNUC__ -D_POSIX_SOURCE -D__STRICT_ANSI__ \
    -Dunix -Di386 -Dlinux -D__unix__ -D__i386__ -D__linux__ -D__signed__=signed \
    -I"$B/include" -I"$B/gcc/include" -I/usr/include \
    prog.c prog.i >/dev/null
node "$wasm/build/rcc.js" -target=x86/mov prog.i prog.s 2>&1 | grep -q 'M/o/Vfuscation complete'
node "$wasm/build/as.js" --32 -o prog.o prog.s >/dev/null
echo "  rcc: $(grep -cE '^[[:space:]]*mov' prog.s) mov instructions; as: prog.o $(wc -c < prog.o) bytes"

# Minimal libc the movfuscator runtime references: sigaction (no-op — movie86
# wires the dispatch itself) and exit (Linux SYS_exit). Same as
# movie86/scripts/link-real-return42.sh.
cat > stubs.s <<'EOF'
.text
.globl sigaction
sigaction:
    movl $0, %eax
    ret
.globl exit
exit:
    movl $1, %eax
    movl 4(%esp), %ebx
    int  $0x80
EOF
as --32 stubs.s -o stubs.o

ld -m elf_i386 -static --hash-style=gnu \
    "$B/crt0.o" prog.o "$B/crtf.o" "$B/crtd.o" "$SF/softfloat32.o" stubs.o \
    -o prog-mov.elf
echo "  linked prog-mov.elf ($(wc -c < prog-mov.elf) bytes, mov-only, static)"

echo "== run under movie86 =="
movie86_bin="$movie86_dir/target/release/movie86"
[ -x "$movie86_bin" ] || movie86_bin="$movie86_dir/target/debug/movie86"
if [ -x "$movie86_bin" ]; then
    "$movie86_bin" prog-mov.elf
else
    (cd "$movie86_dir" && cargo run --quiet --bin movie86 -- "$out/prog-mov.elf")
fi
echo "movie86 exit=$? (0 = ran to completion; crt0 hardcodes exit(0))"
