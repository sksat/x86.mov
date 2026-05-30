#!/usr/bin/env bash
# Milestone 2: link a (mostly) self-hosted rcc.
#
# Builds every translation unit of rcc through the mov pipeline and links them
# into a runnable i386 ELF. 38 of the 39 units are mov-compiled (the whole
# lcc front-end, six backend selectors, and the liblcc runtime
# assert/yynull/bbexit); only the mov backend selector `mov.c` is native i386
# (gcc -m32), because it can't self-compile yet — see run.sh / README wall #3.
#
# Output: $OUT/rcc-selfhost.elf  (OUT defaults to /tmp/movfuscator-selfhost-link)
#
# Status of the result:
#   - it LINKS and STARTS (milestone 2 = done).
#   - it does NOT yet finish a compilation in practical time (milestone 3 is
#     open): the mov-compiled front-end stalls before reaching code generation.
#     Whether that is pure mov slowness or a miscompile in one front-end unit is
#     the next thing to chase. The native rcc compiles the same input instantly,
#     so the invocation/inputs are fine.
#
# MOV_FLOW=0 builds the --no-mov-flow variant (real jumps for control flow, mov
# only for data) against the `_cf` runtime — far less pathological to execute.
# Default (MOV_FLOW=1) is the full SIGILL-dispatch mov-flow build.

set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
wasm="$here/../movfuscator-wasm"
vendor="$wasm/vendor/movfuscator"
src="$vendor/lcc/src"
bld="$vendor/build"
lib="$vendor/lcc/lib"
SF="$vendor/movfuscator/lib"

mov_flow="${MOV_FLOW:-1}"
if [ "$mov_flow" = 0 ]; then
    flow_flag=(--no-mov-flow); crt_sfx="_cf"
else
    flow_flag=();              crt_sfx=""
fi

for f in "$wasm/build/cpp.js" "$wasm/build/rcc.js" "$wasm/build/as.js" \
         "$bld/crt0${crt_sfx}.o" "$bld/crtf${crt_sfx}.o" "$bld/crtd${crt_sfx}.o" \
         "$SF/softfloatfull${crt_sfx}.o" "$bld/mov.c"; do
    if [ ! -e "$f" ]; then
        echo "FAIL: $f missing — set up the sibling toolchain:" >&2
        echo "  (cd $wasm && make setup build-wasm build-wasm-as build-native)" >&2
        exit 1
    fi
done

out="${OUT:-/tmp/movfuscator-selfhost-link}"
mkdir -p "$out"

CPP_FLAGS=(
    -U__GNUC__ -D_POSIX_SOURCE -D__STRICT_ANSI__
    -Dunix -Di386 -Dlinux -D__unix__ -D__i386__ -D__linux__ -D__signed__=signed
    -I"$src" -I"$bld" -I"$vendor/movfuscator"
    -I"$bld/include" -I"$bld/gcc/include" -I/usr/include
)

# rcc translation units, by where their source lives.
FRONT=(alloc bind bytecode dag decl enode error event expr gen init inits input
       lex list main null output prof profio simp stab stmt string symbolic sym
       trace tree types)
GENBACK=(alpha mips sparc x86 x86linux dagcheck)   # mov is handled natively below
LIBLCC=(assert yynull bbexit)

mov_compile() {  # name srcfile -> $out/name.o (mov-only); 0 on success
    local name="$1" c="$2"
    node "$wasm/build/cpp.js" "${CPP_FLAGS[@]}" "$c" "$out/$name.i" >/dev/null 2>&1 || return 1
    node "$wasm/build/rcc.js" -target=x86/mov "${flow_flag[@]}" "$out/$name.i" "$out/$name.s" 2>&1 \
        | grep -q 'M/o/Vfuscation complete' || return 1
    node "$wasm/build/as.js" --32 -o "$out/$name.o" "$out/$name.s" >/dev/null 2>&1
}

echo "== mov-compiling rcc translation units (mov_flow=$mov_flow) =="
n=0; bad=""
for name in "${FRONT[@]}";  do mov_compile "$name" "$src/$name.c" && n=$((n+1)) || bad="$bad $name"; done
for name in "${GENBACK[@]}"; do mov_compile "$name" "$bld/$name.c" && n=$((n+1)) || bad="$bad $name"; done
for name in "${LIBLCC[@]}"; do mov_compile "$name" "$lib/$name.c" && n=$((n+1)) || bad="$bad $name"; done
echo "  $n units mov-compiled${bad:+ (failed:$bad)}"

echo "== mov.c (backend selector) as native i386 — wall #3 holdout =="
gcc -m32 -w -std=gnu89 -c "$bld/mov.c" -I"$src" -I"$bld" -I"$vendor/movfuscator" -o "$out/mov.o"

echo "== link =="
gcc32="$(dirname "$(gcc -m32 -print-libgcc-file-name)")"
objs=()
for f in "${FRONT[@]}" "${GENBACK[@]}" mov "${LIBLCC[@]}"; do objs+=("$out/$f.o"); done
ld -m elf_i386 --hash-style=gnu -dynamic-linker /lib/ld-linux.so.2 \
   --defsym __dso_handle=0 \
   -L"$gcc32" -L/usr/lib32 -L/lib32 \
   "$bld/crt0${crt_sfx}.o" "${objs[@]}" \
   "$bld/crtf${crt_sfx}.o" "$bld/crtd${crt_sfx}.o" "$SF/softfloatfull${crt_sfx}.o" \
   -lgcc -lc -lm -o "$out/rcc-selfhost.elf"
chmod +x "$out/rcc-selfhost.elf"
echo "  linked $out/rcc-selfhost.elf ($(wc -c < "$out/rcc-selfhost.elf") bytes, $(file -b "$out/rcc-selfhost.elf" | cut -d, -f1-2))"
echo
echo "try it (the native rcc does this instantly; the self-hosted one is the open milestone 3):"
echo "  printf 'int main(void){return 0;}\\n' > $out/t.c"
echo "  node $wasm/build/cpp.js ${CPP_FLAGS[*]} $out/t.c $out/t.i"
echo "  $out/rcc-selfhost.elf -target=x86/mov $out/t.i $out/t.s"
