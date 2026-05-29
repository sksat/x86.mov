#!/usr/bin/env bash
# Link the standalone `clang` driver as Emscripten wasm against the
# clang*+LLVM* static libs already built by scripts/build-wasm-llvm.sh.
#
# Output:
#   build/clang.{js,wasm}     — the wasm driver (MODULARIZE + EXPORT_ES6)
#
# Clang's resource-dir headers (lib/clang/<ver>/include/stdarg.h etc.)
# are baked in with `--embed-file` so the wasm module is self-contained
# — no separate lib-bundle fetch needed at runtime. The path layout
# matches a normal install (../lib/clang/<ver>/include/ relative to the
# driver), so clang's default lookup resolves them without flag tuning.

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
llvm_build="$here/build/llvm-wasm"
out="$here/build"

# Match the fail-fast check in build-wasm-llvm-mov-llc.sh so the user
# gets a clear "wasm LLVM not built" hint instead of an opaque ninja
# error when this script is invoked on a fresh tree.
if [ ! -d "$llvm_build/lib/cmake/llvm" ]; then
    echo "wasm LLVM not built — run scripts/build-wasm-llvm.sh first" >&2
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

# Locate where ninja stages the clang-driver compile outputs and the
# resource-dir headers. Building the `clang` *target* itself would
# trigger cmake's own em++ link (no MODULARIZE flags, output named
# `clang.js-22` not `clang.js`) — we skip it and ask ninja for only
# the inputs our own link below needs, saving ~15 min of duplicate
# wasm-opt work on every clean build.
driver_dir="$llvm_build/tools/clang/tools/driver/CMakeFiles/clang.dir"
driver_obj_targets=(
    "tools/clang/tools/driver/CMakeFiles/clang.dir/driver.cpp.o"
    "tools/clang/tools/driver/CMakeFiles/clang.dir/cc1_main.cpp.o"
    "tools/clang/tools/driver/CMakeFiles/clang.dir/cc1as_main.cpp.o"
    "tools/clang/tools/driver/CMakeFiles/clang.dir/cc1gen_reproducer_main.cpp.o"
    "tools/clang/tools/driver/CMakeFiles/clang.dir/clang-driver.cpp.o"
)
# Same cache-restore short-circuit as build-wasm-llvm.sh: if all the
# inputs we'd hand to ninja are already on disk (the cache restored
# them under tools/ and lib/clang/), don't invoke ninja at all — the
# top-level CMakeFiles/ rules.ninja is intentionally not cached and
# ninja would crash trying to load it.
all_present=true
for o in "${driver_obj_targets[@]}"; do
    [ -f "$llvm_build/$o" ] || { all_present=false; break; }
done
if $all_present && [ -d "$llvm_build/lib/clang" ]; then
    echo "clang driver objs + resource headers already on disk; skipping ninja."
else
    ninja -C "$llvm_build" "${driver_obj_targets[@]}" clang-resource-headers \
        2>&1 | tee "$llvm_build/clang.build.log"
fi

if [ ! -d "$driver_dir" ]; then
    echo "expected clang driver object dir at $driver_dir — missing" >&2
    exit 1
fi

# Re-link clang with the same emcc flags we use for llvm-mov-llc so the
# wrapper can call createMovClang() the same way it calls createMovLlc().
# Resource-dir headers were produced by the clang-resource-headers
# target above; the `--embed-file` flag below bakes them into the wasm.
resource_dir="$(ls -d "$llvm_build"/lib/clang/* 2>/dev/null | head -n 1)"
if [ -z "$resource_dir" ] || [ ! -d "$resource_dir/include" ]; then
    echo "clang resource-dir headers not staged at $llvm_build/lib/clang/<ver>/include/" >&2
    echo "the clang-resource-headers target should have produced them" >&2
    exit 1
fi
resource_ver="$(basename "$resource_dir")"

EMCC_FLAGS=(
    "-sMODULARIZE=1"
    "-sEXPORT_ES6=1"
    "-sEXPORT_NAME=createMovClang"
    "-sENVIRONMENT=web,node,worker"
    "-sFORCE_FILESYSTEM=1"
    "-sINVOKE_RUN=0"
    "-sEXIT_RUNTIME=1"
    "-sALLOW_MEMORY_GROWTH=1"
    "-sINITIAL_MEMORY=128MB"
    "-sSTACK_SIZE=8MB"
    "-sEXPORTED_RUNTIME_METHODS=['callMain','FS']"
    "--embed-file" "$resource_dir/include@/lib/clang/$resource_ver/include"
)

# Collect every clang driver / front-end object file produced by the
# ninja build above. Driver entry is in tools/driver/ (driver.cpp,
# cc1_main.cpp, cc1as_main.cpp, cc1gen_reproducer_main.cpp). They link
# against the clang* + LLVM* static libs in lib/.
driver_objs=()
while IFS= read -r o; do
    driver_objs+=("$o")
done < <(find "$driver_dir" -name '*.o' | sort)
if [ ${#driver_objs[@]} -eq 0 ]; then
    echo "no clang driver .o files found under $driver_dir" >&2
    exit 1
fi

# Static libs in link order: clang* first (they're the consumers), then
# LLVM* below them.
clang_libs=()
while IFS= read -r l; do
    clang_libs+=("$l")
done < <(find "$llvm_build/lib" -maxdepth 1 -name 'libclang*.a' | sort)
llvm_libs=()
while IFS= read -r l; do
    llvm_libs+=("$l")
done < <(find "$llvm_build/lib" -maxdepth 1 -name 'libLLVM*.a' | sort)

mkdir -p "$out"
em++ "${EMCC_FLAGS[@]}" \
    -o "$out/clang.js" \
    "${driver_objs[@]}" \
    "${clang_libs[@]}" \
    "${llvm_libs[@]}" \
    2>&1 | tee "$llvm_build/clang.link.log"

if [ ! -f "$out/clang.wasm" ]; then
    echo "clang.wasm not produced — see $llvm_build/clang.link.log" >&2
    exit 1
fi

# Zstandard-compress clang.wasm for the deploy. clang.wasm itself is
# ~80 MiB, well over Cloudflare Pages' 25 MiB/file upload cap.
# `zstd -19 --long=23` brings it to ~16 MiB (5×) — fits in one file
# and ~25 % smaller than gzip -9. The browser handles decompression
# natively (`Content-Encoding: zstd` set in `_headers` at stage-deploy
# time; Chrome 123+/Firefox 126+/Edge 123+ all ship it), so the
# wrapper just fetches the .zst URL and feeds the bytes Emscripten
# without touching any decompression library.
#
# Window-size cap: `Content-Encoding: zstd` is governed by RFC 8878,
# which lets clients reject frames with a window size > 8 MiB
# (2^23). Chromium enforces that cap as a hard `net::ERR_ZSTD_
# WINDOW_SIZE_TOO_BIG` — anything larger gets refused at the network
# layer before our wrapper sees a single byte. `--long=23` pins the
# encoder to that ceiling. Browsers without native zstd take the
# fzstd JS path instead, which doesn't share the limit, but we still
# encode for the strictest consumer so a single artefact serves both.
#
# The original .wasm stays in place for local dev (Emscripten's
# default loader fetches the uncompressed clang.wasm next to clang.js
# when the wrapper has no version pinned in wasm-config.js).
#
# (We used to ship `clang.wasm.part-{0..N}` chunks with a client-side
# concat, then briefly used .gz; clean up either flavour so a fresh
# build doesn't leave stale ones behind.)
rm -f "$out"/clang.wasm.part-* "$out/clang.wasm.gz" "$out/clang.wasm.zst"
zstd -19 --long=23 -f -o "$out/clang.wasm.zst" "$out/clang.wasm"

# Content-hash of clang.wasm (first 12 hex of SHA-256). stage-deploy.sh
# embeds this in the deployed .zst filename so the URL changes on a
# content bump — the browser's HTTP cache (`Cache-Control: immutable`
# set via `_headers`) then keeps the bytes forever between page loads,
# and a real binary update naturally invalidates the cache via the new
# URL. Local dev doesn't care about caching, so this file is
# informational here.
sha256sum "$out/clang.wasm" | awk '{ print substr($1, 1, 12) }' > "$out/clang.wasm.hash"

# Reuse the {"type":"module"} marker produced by the llvm-mov-llc
# staging step (build/package.json already exists if that script ran);
# write it ourselves otherwise.
if [ ! -f "$out/package.json" ]; then
    echo '{"type":"module"}' > "$out/package.json"
fi

echo "wasm clang build complete:"
ls -la "$out"/clang.{js,wasm} "$out/clang.wasm.zst" "$out/clang.wasm.hash"
