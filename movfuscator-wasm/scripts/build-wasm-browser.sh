#!/usr/bin/env bash
# Browser-mode wasm build for cpp + rcc.
#
# Differs from build-wasm.sh / build-wasm-cpp.sh in three ways:
#   1. MEMFS (no NODERAWFS) so it works in the browser.
#   2. ES6 module output with MODULARIZE, named factory exports.
#   3. System + LCC headers are baked into the wasm via --embed-file.
#
# Output: build/browser/cpp.{js,wasm} + build/browser/rcc.{js,wasm}

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
vendor="$here/vendor/movfuscator"
out="$here/build/browser"
embed="$here/build/embed-headers"

if [ -z "${EMSDK:-}" ]; then
    if [ -f "$HOME/emsdk/emsdk_env.sh" ]; then
        # shellcheck disable=SC1091
        EMSDK_QUIET=1 source "$HOME/emsdk/emsdk_env.sh" > /dev/null
    else
        echo "emsdk not found; install to \$HOME/emsdk or source emsdk_env.sh" >&2
        exit 1
    fi
fi

if [ ! -d "$vendor" ]; then
    echo "vendor missing; run scripts/fetch.sh first" >&2
    exit 1
fi

if [ ! -f "$vendor/build/mov.c" ]; then
    echo "lburg-generated sources missing; running build-native.sh"
    "$here/scripts/build-native.sh"
fi

# Always re-collect so a fixture adding a new #include is picked up.
"$here/scripts/collect-headers.sh"

mkdir -p "$out"

CFLAGS=(
    -O2 -g0
    -Wno-error=implicit-int
    -Wno-error=implicit-function-declaration
    -Wno-error=int-conversion
    -Wno-error=incompatible-pointer-types
    -Wno-error=implicit-int-conversion
    -Wno-implicit-int
    -Wno-implicit-function-declaration
)

EMCC_COMMON=(
    -sMODULARIZE=1
    -sEXPORT_ES6=1
    -sENVIRONMENT=web,node,worker
    -sFORCE_FILESYSTEM=1
    -sEXIT_RUNTIME=1
    -sALLOW_MEMORY_GROWTH=1
    -sINVOKE_RUN=0
    "-sEXPORTED_RUNTIME_METHODS=['callMain','FS']"
    --embed-file "$embed/usr-include@/usr/include"
    --embed-file "$vendor/build/include@/lcc-include"
    --embed-file "$vendor/build/gcc/include/stddef.h@/gcc-include/stddef.h"
)

###############################################################################
# cpp
###############################################################################
CPP_SRC=(cpp lex nlist tokens macro eval include hideset getopt unix)
cpp_objs=()
for f in "${CPP_SRC[@]}"; do
    obj="$out/cpp-$f.o"
    emcc "${CFLAGS[@]}" -I"$vendor/lcc/cpp" -c "$vendor/lcc/cpp/$f.c" -o "$obj"
    cpp_objs+=("$obj")
done
emcc "${cpp_objs[@]}" \
    -o "$out/cpp.js" \
    "${EMCC_COMMON[@]}" \
    -sEXPORT_NAME=createMovCpp

###############################################################################
# rcc
###############################################################################
RCC_SRC=(
    alloc bind bytecode dag decl enode error event expr gen
    init inits input lex list main null output prof profio simp stab
    stmt string sym symbolic trace tree types
)
RCC_GEN=(alpha dagcheck mips mov sparc x86 x86linux)

rcc_objs=()
for f in "${RCC_SRC[@]}"; do
    obj="$out/rcc-$f.o"
    emcc "${CFLAGS[@]}" -I"$vendor/lcc/src" -I"$vendor/movfuscator" -c "$vendor/lcc/src/$f.c" -o "$obj"
    rcc_objs+=("$obj")
done
for f in "${RCC_GEN[@]}"; do
    obj="$out/rcc-$f.o"
    emcc "${CFLAGS[@]}" -I"$vendor/lcc/src" -I"$vendor/movfuscator" -c "$vendor/build/$f.c" -o "$obj"
    rcc_objs+=("$obj")
done
emcc "${rcc_objs[@]}" \
    -o "$out/rcc.js" \
    "${EMCC_COMMON[@]}" \
    -sEXPORT_NAME=createMovRcc

echo
echo "browser-mode build complete:"
ls -la "$out"/{cpp,rcc}.{js,wasm}
