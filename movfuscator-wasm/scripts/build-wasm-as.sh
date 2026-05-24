#!/usr/bin/env bash
# Build GNU as (from binutils 2.44) targeting i386-linux as a wasm artifact.
#
# Output: build/as.{js,wasm} — equivalent to /usr/bin/as for our .s inputs.
# Uses NODERAWFS so it can read host paths from Node directly (mirrors
# build-wasm.sh / build-wasm-cpp.sh).
#
# Quirks worth knowing:
# - emconfigure compiles binutils' build-helper tools (chew etc.) as wasm,
#   but they're invoked as host executables during the build. We rebuild
#   chew natively after configure so doc generation works.
# - Patches under patches/binutils-2.44/ are applied by fetch.sh; this
#   script assumes the source tree is already prepared.
# - --without-zlib avoids needing Emscripten's zlib port for now.

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
src="$here/vendor/binutils-2.44"
build="$here/build/binutils-as"
out="$here/build"

if [ ! -d "$src" ]; then
    echo "binutils source missing at $src — run scripts/fetch.sh" >&2
    exit 1
fi

if [ -z "${EMSDK:-}" ]; then
    if [ -f "$HOME/emsdk/emsdk_env.sh" ]; then
        # shellcheck disable=SC1091
        EMSDK_QUIET=1 source "$HOME/emsdk/emsdk_env.sh" > /dev/null
    else
        echo "emsdk not found; install to \$HOME/emsdk" >&2
        exit 1
    fi
fi

mkdir -p "$build"
cd "$build"

if [ ! -f Makefile ]; then
    emconfigure "$src/configure" \
        --target=i386-linux-gnu \
        --disable-werror --disable-nls --disable-shared \
        --disable-gold --disable-ld --disable-gdb --disable-gdbserver \
        --disable-libquadmath --disable-libada --disable-libstdcxx \
        --disable-libssp --disable-libgm2 --disable-gprofng \
        --disable-binutils --disable-readline --disable-libdecnumber \
        --disable-sim --disable-isl-version-check \
        --disable-bootstrap \
        --without-zlib --without-zstd \
        > configure.log 2>&1
fi

# chew is a small doc generator in bfd/doc/. Without this it's built by
# emcc into a Node.js shim that the binutils Makefile can't execute as a
# host program — substitute a native binary.
if [ ! -x "$build/bfd/doc/chew" ] || ! file "$build/bfd/doc/chew" | grep -q ELF; then
    mkdir -p "$build/bfd/doc"
    cc -O2 -o "$build/bfd/doc/chew" "$src/bfd/doc/chew.c"
fi

# all-gas pulls in libiberty, bfd, libsframe, opcodes etc. as
# dependencies. NODERAWFS at link time lets the final as-new read host
# paths directly from Node.
emmake make -j"$(nproc)" \
    MAKEINFO=true \
    LDFLAGS="-sNODERAWFS=1 -sALLOW_MEMORY_GROWTH=1" \
    all-gas 2> "$build/build.log" | tail -5

asbin="$build/gas/as-new"
if [ ! -f "$asbin.wasm" ]; then
    echo "as.wasm not produced; tail of build.log:" >&2
    tail -40 "$build/build.log" >&2
    exit 1
fi

cp "$asbin"      "$out/as.js"
cp "$asbin.wasm" "$out/as.wasm"
# The emcc-generated .js bakes in the wasm filename ('as-new.wasm').
# Patch it to use our renamed artifact so the .js is portable to
# build/as.{js,wasm}.
sed -i "s/'as-new\.wasm'/'as.wasm'/g" "$out/as.js"

echo "wasm-as build complete:"
ls -la "$out"/as.{js,wasm}
