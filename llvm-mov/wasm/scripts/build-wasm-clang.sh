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
ninja -C "$llvm_build" "${driver_obj_targets[@]}" clang-resource-headers \
    2>&1 | tee "$llvm_build/clang.build.log"

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

# Reuse the {"type":"module"} marker produced by the llvm-mov-llc
# staging step (build/package.json already exists if that script ran);
# write it ourselves otherwise.
if [ ! -f "$out/package.json" ]; then
    echo '{"type":"module"}' > "$out/package.json"
fi

echo "wasm clang build complete:"
ls -la "$out"/clang.{js,wasm}
