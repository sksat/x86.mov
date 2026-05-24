#!/usr/bin/env bash
# Re-link wasm-ld for browser mode (MEMFS, ES module) — Phase E-2.
#
# No --embed-file at link time; the demo / wrapper fetches the link inputs
# (crt0/crtf/crtd/softfloat32/libc/libm/libgcc/ld-linux) on demand and
# writes them into MEMFS via FS.writeFile. Keeps the ld.wasm download
# itself small (~8 MB) and lets the ~23 MB of supporting libraries land
# only when the user actually clicks Download ELF.

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

cd "$build/ld"
rm -f ld-new ld-new.wasm
emmake make LDFLAGS="-sMODULARIZE=1 -sEXPORT_ES6=1 \
        -sEXPORT_NAME=createMovLd \
        -sENVIRONMENT=web,node,worker \
        -sFORCE_FILESYSTEM=1 -sEXIT_RUNTIME=1 -sALLOW_MEMORY_GROWTH=1 \
        -sINVOKE_RUN=0 \
        -sEXPORTED_RUNTIME_METHODS=['callMain','FS']" \
    ld-new 2>&1 | tail -3

cp ld-new      "$out/ld.js"
cp ld-new.wasm "$out/ld.wasm"
sed -i "s/'ld-new\.wasm'/'ld.wasm'/g" "$out/ld.js"

# Restore the NODERAWFS variant so 'make test-ld' keeps working.
rm -f ld-new ld-new.wasm
emmake make LDFLAGS="-sNODERAWFS=1 -sALLOW_MEMORY_GROWTH=1" ld-new 2>&1 | tail -3
cp ld-new      "$here/build/ld.js"
cp ld-new.wasm "$here/build/ld.wasm"
sed -i "s/'ld-new\.wasm'/'ld.wasm'/g" "$here/build/ld.js"

echo
echo "browser ld build complete:"
ls -la "$out"/ld.{js,wasm}
