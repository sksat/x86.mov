#!/usr/bin/env bash
# Compile LCC's bundled cpp (preprocessor) to WebAssembly via Emscripten.
# Output: build/cpp.js + build/cpp.wasm.
#
# Decoupling from the system /usr/bin/cpp lets the whole .c → .s pipeline
# run inside wasm, and avoids the C99-isms in modern glibc headers
# (upstream issue #51) since LCC ships its own C89 stdio.h etc.

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

if [ ! -d "$vendor/lcc/cpp" ]; then
    echo "vendor missing; run scripts/fetch.sh first" >&2
    exit 1
fi

mkdir -p "$out"
echo '{"type":"commonjs"}' > "$out/package.json"
cd "$vendor"

# Same relaxations as rcc — Emscripten's clang is strict by default.
CFLAGS=(
    -O2 -g0
    -Ilcc/cpp
    -Wno-error=implicit-int
    -Wno-error=implicit-function-declaration
    -Wno-error=int-conversion
    -Wno-error=incompatible-pointer-types
    -Wno-error=implicit-int-conversion
    -Wno-implicit-int
    -Wno-implicit-function-declaration
)

# Source files match the CPPOBJS list in lcc/makefile.
SRC=(cpp lex nlist tokens macro eval include hideset getopt unix)

objs=()
for f in "${SRC[@]}"; do
    obj="$out/cpp-$f.o"
    emcc "${CFLAGS[@]}" -c "lcc/cpp/$f.c" -o "$obj"
    objs+=("$obj")
done

emcc "${objs[@]}" \
    -o "$out/cpp.js" \
    -sFORCE_FILESYSTEM=1 \
    -sEXIT_RUNTIME=1 \
    -sALLOW_MEMORY_GROWTH=1 \
    -sNODERAWFS=1

echo "wasm cpp build complete:"
ls -la "$out"/cpp.{js,wasm}
