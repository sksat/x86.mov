#!/usr/bin/env bash
# Test wasm-ld against host /usr/bin/ld.
#
# For each tests/goldens-o/*.o, link with the same flag set on both ld
# implementations and cmp the resulting ELF32 executables. ELF outputs
# are ~11 MB each, so they're not committed — the host's /usr/bin/ld
# acts as the reference and must be available.

set -uo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
goldens_o="$here/tests/goldens-o"
ldjs="$here/build/ld.js"

B="$here/vendor/movfuscator/build"
SF="$here/vendor/movfuscator/movfuscator/lib"
CRT_FILES=("$B/crt0.o" "$B/crtf.o" "$B/crtd.o" "$SF/softfloat32.o")
LIB_PATHS=(-L"$B" -L"$B/gcc/32" -L/usr/lib32 -L/lib32)
COMMON_FLAGS=(-m elf_i386 --hash-style=gnu -dynamic-linker /lib/ld-linux.so.2
              -lgcc -lc -lm)

if [ -z "${EMSDK:-}" ] && [ -f "$HOME/emsdk/emsdk_env.sh" ]; then
    # shellcheck disable=SC1091
    EMSDK_QUIET=1 source "$HOME/emsdk/emsdk_env.sh" > /dev/null
fi

if [ ! -f "$ldjs" ]; then
    echo "FAIL: $ldjs missing; run 'make build-wasm-as' first" >&2
    exit 1
fi
for f in "${CRT_FILES[@]}"; do
    if [ ! -f "$f" ]; then
        echo "FAIL: $f missing; run 'make build-native' first" >&2
        exit 1
    fi
done
if ! command -v ld > /dev/null; then
    echo "FAIL: host /usr/bin/ld missing — apt install binutils" >&2
    exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

pass=0; fail=0
for o in "$goldens_o"/*.o; do
    name="$(basename "$o" .o)"
    nelf="$tmp/$name.native.elf"
    welf="$tmp/$name.wasm.elf"

    if ! ld "${COMMON_FLAGS[@]}" "${LIB_PATHS[@]}" \
            "$B/crt0.o" "$o" "$B/crtf.o" "$B/crtd.o" "$SF/softfloat32.o" \
            -o "$nelf" 2> "$tmp/$name.native.err"; then
        echo "FAIL $name — native ld failed"
        sed 's/^/  | /' "$tmp/$name.native.err" | head -5
        fail=$((fail+1))
        continue
    fi

    if ! node "$ldjs" "${COMMON_FLAGS[@]}" "${LIB_PATHS[@]}" \
            "$B/crt0.o" "$o" "$B/crtf.o" "$B/crtd.o" "$SF/softfloat32.o" \
            -o "$welf" 2> "$tmp/$name.wasm.err"; then
        echo "FAIL $name — wasm ld failed"
        sed 's/^/  | /' "$tmp/$name.wasm.err" | head -5
        fail=$((fail+1))
        continue
    fi

    if cmp -s "$nelf" "$welf"; then
        echo "PASS $name ($(stat -c %s "$nelf") bytes)"
        pass=$((pass+1))
    else
        echo "FAIL $name — wasm ELF differs from native"
        echo "  | native=$(stat -c %s "$nelf") wasm=$(stat -c %s "$welf")"
        fail=$((fail+1))
    fi
done

echo
echo "results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
