#!/usr/bin/env bash
# Test runner: for every tests/fixtures/*.c, run the wasm rcc on the
# preprocessed form and assert the output is byte-identical to the
# committed golden in tests/goldens/.
#
# This is the core TDD safety net for the wasm port: any code change
# that perturbs codegen will fail loudly here.

set -uo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
fixtures="$here/tests/fixtures"
goldens="$here/tests/goldens"
rccjs="$here/build/rcc.js"

if [ -z "${EMSDK:-}" ] && [ -f "$HOME/emsdk/emsdk_env.sh" ]; then
    # shellcheck disable=SC1091
    EMSDK_QUIET=1 source "$HOME/emsdk/emsdk_env.sh" > /dev/null
fi

if [ ! -f "$rccjs" ]; then
    echo "FAIL: $rccjs missing; run 'make build-wasm' first" >&2
    exit 1
fi

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
    "$here/scripts/preprocess.sh" "$c" "$i" 2> "$tmp/$name.cpp.err"
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
