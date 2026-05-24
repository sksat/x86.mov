#!/usr/bin/env bash
# Compile rcc to WebAssembly via Emscripten.
# Reuses the lburg-generated .c files produced by build-native.sh, which
# is invoked automatically if those files are absent.

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
vendor="$here/vendor/movfuscator"
out="$here/build"

if [ -z "${EMSDK:-}" ]; then
    if [ -f "$HOME/emsdk/emsdk_env.sh" ]; then
        # shellcheck disable=SC1091
        EMSDK_QUIET=1 source "$HOME/emsdk/emsdk_env.sh" > /dev/null
    else
        echo "emsdk not found; install to \$HOME/emsdk or source emsdk_env.sh" >&2
        exit 1
    fi
fi

if [ ! -f "$vendor/build/mov.c" ]; then
    echo "lburg-generated sources missing; running build-native.sh"
    "$here/scripts/build-native.sh"
fi

mkdir -p "$out"
# Emscripten's NODERAWFS .js loader is CommonJS (uses require). The npm
# package.json one level up sets "type": "module", which would force Node
# to parse build/*.js as ESM and crash. Pin this subtree to commonjs.
echo '{"type":"commonjs"}' > "$out/package.json"
cd "$vendor"

# Same workaround flags as build.sh.gcc14.patch — Emscripten's clang is also
# strict about implicit-int / implicit-function-declaration / int-conversion.
CFLAGS=(
    -O2 -g0
    -Ilcc/src -Imovfuscator
    -Wno-error=implicit-int
    -Wno-error=implicit-function-declaration
    -Wno-error=int-conversion
    -Wno-error=incompatible-pointer-types
    -Wno-error=implicit-int-conversion
    -Wno-implicit-int
    -Wno-implicit-function-declaration
)

SRC=(
    alloc bind bytecode dag decl enode error event expr gen
    init inits input lex list main null output prof profio simp stab
    stmt string sym symbolic trace tree types
)

GEN=(alpha dagcheck mips mov sparc x86 x86linux)

objs=()
for f in "${SRC[@]}"; do
    obj="$out/$f.o"
    emcc "${CFLAGS[@]}" -c "lcc/src/$f.c" -o "$obj"
    objs+=("$obj")
done

for f in "${GEN[@]}"; do
    obj="$out/$f.o"
    emcc "${CFLAGS[@]}" -c "build/$f.c" -o "$obj"
    objs+=("$obj")
done

emcc "${objs[@]}" \
    -o "$out/rcc.js" \
    -sFORCE_FILESYSTEM=1 \
    -sEXIT_RUNTIME=1 \
    -sALLOW_MEMORY_GROWTH=1 \
    -sNODERAWFS=1

echo "wasm build complete:"
ls -la "$out"/rcc.{js,wasm}
