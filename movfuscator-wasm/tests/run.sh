#!/usr/bin/env bash
# End-to-end wasm pipeline test runner.
#
# For each tests/fixtures/*.c:
#   1. wasm cpp  → .i  (build/cpp.js)
#   2. wasm rcc  → .s  (build/rcc.js)
#   3. cmp .s against committed tests/goldens/*.s
#
# This is the core TDD safety net: a byte-level regression in either
# wasm-compiled tool fails loudly.

set -uo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
fixtures="$here/tests/fixtures"
goldens="$here/tests/goldens"
vendor="$here/vendor/movfuscator"
cppjs="$here/build/cpp.js"
rccjs="$here/build/rcc.js"

if [ -z "${EMSDK:-}" ] && [ -f "$HOME/emsdk/emsdk_env.sh" ]; then
    # shellcheck disable=SC1091
    EMSDK_QUIET=1 source "$HOME/emsdk/emsdk_env.sh" > /dev/null
fi

for required in "$cppjs" "$rccjs"; do
    if [ ! -f "$required" ]; then
        echo "FAIL: $required missing; run 'make build-wasm' first" >&2
        exit 1
    fi
done

inc1="$vendor/build/include"
inc2="$vendor/build/gcc/include"
if [ ! -d "$inc1" ] || [ ! -d "$inc2" ]; then
    echo "FAIL: lcc include dirs missing; run 'make build-native' first" >&2
    exit 1
fi

# Same predefined macros and include search order the native lcc driver uses.
CPP_FLAGS=(
    -U__GNUC__ -D_POSIX_SOURCE -D__STRICT_ANSI__
    -Dunix -Di386 -Dlinux
    -D__unix__ -D__i386__ -D__linux__
    -D__signed__=signed
    -D__LCC__
    -I"$inc1" -I"$inc2" -I/usr/include
)

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
for c in "$fixtures"/*.c; do
    name="$(basename "$c" .c)"
    golden="$goldens/$name.s"
    if [ ! -f "$golden" ]; then
        echo "SKIP $name (no golden — run 'make goldens')"
        continue
    fi
    i="$tmp/$name.i"
    s="$tmp/$name.s"

    if ! node "$cppjs" "${CPP_FLAGS[@]}" "$c" "$i" > "$tmp/$name.cpp.out" 2>&1; then
        echo "FAIL $name — wasm cpp failed"
        sed 's/^/  | /' "$tmp/$name.cpp.out"
        fail=$((fail+1))
        continue
    fi
    node "$rccjs" -target=x86/mov "$i" "$s" > "$tmp/$name.rcc.out" 2>&1 || true
    if [ ! -f "$s" ]; then
        echo "FAIL $name — wasm rcc produced no output"
        sed 's/^/  | /' "$tmp/$name.rcc.out"
        fail=$((fail+1))
        continue
    fi
    if cmp -s "$s" "$golden"; then
        echo "PASS $name ($(wc -l < "$s") lines)"
        pass=$((pass+1))
    else
        echo "FAIL $name — wasm output differs from golden"
        diff -u "$golden" "$s" | head -20 | sed 's/^/  | /'
        fail=$((fail+1))
    fi
done

echo
echo "results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
