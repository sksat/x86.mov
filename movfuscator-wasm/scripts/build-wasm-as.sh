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
    # tee instead of plain `> configure.log` so a configure failure
    # surfaces in CI logs (otherwise `make: Error 1` from this step is
    # opaque — happened on the first post-merge deploy run).
    # --host=wasm32-unknown-emscripten makes autoconf treat this as a
    # cross-build (build != host), skipping the "can we run a compiled
    # program?" check that otherwise fails with emcc-produced wasm.
    # emconfigure sets CC=emcc but doesn't pass --host on its own, so
    # binutils' configure would see the native build triple and crash.
    emconfigure "$src/configure" \
        --host=wasm32-unknown-emscripten \
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
        2>&1 | tee configure.log
fi

# Belt + suspenders for build-time helpers. configure-side CC_FOR_BUILD
# above should be enough on a sensible host, but on the GitHub Actions
# runner emconfigure still routed chew's compile through emcc, so:
#   1. pre-build chew natively before make starts, so the rule's first
#      "is up-to-date" check passes without invoking the CCLD recipe;
#   2. pass CC_FOR_BUILD=cc to make explicitly so any other helper that
#      needs rebuilding (genscripts, etc.) doesn't slip back to emcc.
if [ ! -x "$build/bfd/doc/chew" ] || ! file "$build/bfd/doc/chew" | grep -q ELF; then
    mkdir -p "$build/bfd/doc"
    cc -O2 -o "$build/bfd/doc/chew" "$src/bfd/doc/chew.c"
fi

# all-gas pulls in libiberty, bfd, libsframe, opcodes etc. as
# dependencies. NODERAWFS at link time lets the final binaries read host
# paths directly from Node. Output is teed so any failure shows up in
# CI logs (set -e + pipefail still fail the script on make's non-zero).
emmake make -j"$(nproc)" \
    MAKEINFO=true \
    CC_FOR_BUILD=cc \
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

mkdir -p "$out"
echo '{"type":"commonjs"}' > "$out/package.json"

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
