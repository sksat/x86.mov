#!/usr/bin/env bash
# Re-link wasm-as for browser mode (MEMFS, ES module).
#
# Reuses the already-built .o files in build/binutils-as/ (set up by
# scripts/build-wasm-as.sh) — only the final emcc link gets re-run with
# browser flags. Output: build/browser/as.{js,wasm}.

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
build="$here/build/binutils-as"
out="$here/build/browser"

if [ ! -f "$build/Makefile" ]; then
    echo "binutils-as build missing — run scripts/build-wasm-as.sh first" >&2
    exit 1
fi

if [ -z "${EMSDK:-}" ]; then
    if [ -f "$HOME/emsdk/emsdk_env.sh" ]; then
        # shellcheck disable=SC1091
        EMSDK_QUIET=1 source "$HOME/emsdk/emsdk_env.sh" > /dev/null
    fi
fi

mkdir -p "$out"

cd "$build/gas"
rm -f as-new as-new.wasm
# tee — not `| tail` — so a failed relink shows its actual diagnostic
# in CI logs. set -e + pipefail still aborts on emmake's non-zero.
emmake make LDFLAGS="-sMODULARIZE=1 -sEXPORT_ES6=1 \
        -sEXPORT_NAME=createMovAs \
        -sENVIRONMENT=web,node,worker \
        -sFORCE_FILESYSTEM=1 -sEXIT_RUNTIME=1 -sALLOW_MEMORY_GROWTH=1 \
        -sINVOKE_RUN=0 \
        -sEXPORTED_RUNTIME_METHODS=['callMain','FS']" \
    as-new 2>&1 | tee "$build/relink-browser.log"

cp as-new      "$out/as.js"
cp as-new.wasm "$out/as.wasm"
sed -i "s/'as-new\.wasm'/'as.wasm'/g" "$out/as.js"

# Restore the NODERAWFS as-new (re-link so 'make test-as' keeps working).
rm -f as-new as-new.wasm
emmake make LDFLAGS="-sNODERAWFS=1 -sALLOW_MEMORY_GROWTH=1" as-new 2>&1 | tee "$build/relink-noderawfs.log"
cp as-new      "$here/build/as.js"
cp as-new.wasm "$here/build/as.wasm"
sed -i "s/'as-new\.wasm'/'as.wasm'/g" "$here/build/as.js"

echo
echo "browser as build complete:"
ls -la "$out"/as.{js,wasm}
