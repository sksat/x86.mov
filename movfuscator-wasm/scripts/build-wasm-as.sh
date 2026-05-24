#!/usr/bin/env bash
# Build GNU as and ld (from binutils 2.44) targeting i386-linux as wasm
# artifacts.
#
# Output:
#   build/as.{js,wasm}  — equivalent to /usr/bin/as for our .s inputs
#   build/ld.{js,wasm}  — equivalent to /usr/bin/ld for our link step
#
# Both use NODERAWFS so they can read host paths from Node directly
# (mirrors build-wasm.sh / build-wasm-cpp.sh).
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
    # CC_FOR_BUILD has to be a host compiler: binutils builds helper
    # programs (bfd/doc/chew, ld/genscripts.sh callees, etc.) that have
    # to run on the build machine, not the wasm target. emconfigure sets
    # CC=emcc but leaves CC_FOR_BUILD inheriting the same value unless
    # we override it.
    emconfigure "$src/configure" \
        --target=i386-linux-gnu \
        --disable-werror --disable-nls --disable-shared \
        --disable-gold --disable-gdb --disable-gdbserver \
        --disable-libquadmath --disable-libada --disable-libstdcxx \
        --disable-libssp --disable-libgm2 --disable-gprofng \
        --disable-binutils --disable-readline --disable-libdecnumber \
        --disable-sim --disable-isl-version-check \
        --disable-bootstrap \
        --without-zlib --without-zstd \
        CC_FOR_BUILD=cc \
        > configure.log 2>&1
fi

# all-gas pulls in libiberty, bfd, libsframe, opcodes etc. as
# dependencies. NODERAWFS at link time lets the final binaries read host
# paths directly from Node. Output is teed so any failure shows up in
# CI logs (set -e + pipefail still fail the script on make's non-zero).
emmake make -j"$(nproc)" \
    MAKEINFO=true \
    LDFLAGS="-sNODERAWFS=1 -sALLOW_MEMORY_GROWTH=1" \
    all-gas all-ld 2>&1 | tee "$build/build.log"

asbin="$build/gas/as-new"
ldbin="$build/ld/ld-new"
for b in "$asbin" "$ldbin"; do
    if [ ! -f "$b.wasm" ]; then
        echo "${b##*/}.wasm not produced; tail of build.log:" >&2
        tail -40 "$build/build.log" >&2
        exit 1
    fi
done

cp "$asbin"      "$out/as.js"
cp "$asbin.wasm" "$out/as.wasm"
cp "$ldbin"      "$out/ld.js"
cp "$ldbin.wasm" "$out/ld.wasm"

# The emcc-generated .js bakes in the wasm filename ('as-new.wasm' /
# 'ld-new.wasm'). Patch them to use our renamed artifacts.
sed -i "s/'as-new\.wasm'/'as.wasm'/g" "$out/as.js"
sed -i "s/'ld-new\.wasm'/'ld.wasm'/g" "$out/ld.js"

echo "wasm-as + wasm-ld build complete:"
ls -la "$out"/as.{js,wasm} "$out"/ld.{js,wasm}
