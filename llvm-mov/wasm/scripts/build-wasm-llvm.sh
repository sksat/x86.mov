#!/usr/bin/env bash
# Build LLVM 22.1.x as Emscripten static libs, plus clang's static
# libs and headers (for the C-input demo path).
#
# Output:
#   build/llvm-wasm/                — Ninja build dir
#     lib/libLLVM*.a + libclang*.a  — wasm static libraries
#     lib/cmake/llvm/               — what our backend's find_package(LLVM) points at
#     lib/cmake/clang/              — likewise for the clang frontend wasm
#     lib/clang/<ver>/include/      — clang resource-dir headers (stdarg.h etc.)
#
# This is the slow step (~45–120 minutes on a 4-core machine). The
# subsequent backend + clang driver link steps are fast in comparison.
#
# Quirks worth knowing:
# - LLVM_TARGETS_TO_BUILD is intentionally empty. The Mov target is the
#   only one we use and it's registered out-of-tree by the backend libs.
#   Building X86 / AArch64 / etc. in-tree would balloon the wasm by
#   tens of MB for code that's never reached. Clang's frontend doesn't
#   need a backend either — it emits LLVM IR via `-emit-llvm`, with
#   target info coming from clang's own driver tables, not LLVM CodeGen.
# - LLVM_TABLEGEN points at the system llvm-tblgen so TableGen
#   invocations don't have to round-trip through Node + wasm. Same
#   pattern movfuscator-wasm uses for binutils' chew.
# - LLVM_INCLUDE_{TESTS,EXAMPLES,BENCHMARKS} are all OFF to skip the
#   gtest/google-benchmark builds Emscripten would otherwise drag in.
# - LLVM_BUILD_TOOLS=OFF / LLVM_BUILD_UTILS=OFF — we don't need llc,
#   opt, etc. as wasm; our llvm-mov-llc + clang drivers are the only
#   tools that get emcc-linked.

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
src="$here/vendor/llvm-project/llvm"
build="$here/build/llvm-wasm"

if [ ! -d "$src" ]; then
    echo "LLVM source missing at $src — run scripts/fetch.sh first" >&2
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

# System tblgen — must match the LLVM source version. fetch.sh pins the
# source to llvmorg-22.1.x and the apt.llvm.org install is the same line.
SYSTEM_TBLGEN="${LLVM_TABLEGEN:-/usr/lib/llvm-22/bin/llvm-tblgen}"
if [ ! -x "$SYSTEM_TBLGEN" ]; then
    echo "system llvm-tblgen missing at $SYSTEM_TBLGEN" >&2
    echo "install with: sudo apt-get install llvm-22-dev" >&2
    exit 1
fi

mkdir -p "$build"

# Cache-restore detection. actions/cache only restores the explicit
# paths we listed (lib/, bin/, include/, tools/ and the ninja top-level
# files), not the multi-GB `CMakeFiles/` intermediate state. If lib/
# was restored and CMakeFiles/ is missing, the cached static libs are
# usable directly — build-wasm-llvm-mov-llc and build-wasm-clang only
# need them and the cmake config dir. Asking ninja to "rebuild" would
# dereference references into the missing CMakeFiles/ tree and crash,
# so bail out early and let downstream steps consume the cache.
if [ -f "$build/lib/cmake/llvm/LLVMConfig.cmake" ] && [ ! -d "$build/CMakeFiles" ]; then
    echo "build/llvm-wasm/ restored from cache (no CMakeFiles/); skipping ninja."
    exit 0
fi

# Idempotent: skip the configure step if it already ran. Re-running
# emcmake on a configured build dir is harmless but cmake re-walks the
# whole config which is ~30 s of pointless work on warm builds.
if [ ! -f "$build/build.ninja" ]; then
    emcmake cmake -S "$src" -B "$build" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLVM_TARGETS_TO_BUILD="" \
        -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD="" \
        -DLLVM_ENABLE_PROJECTS="clang" \
        -DCLANG_ENABLE_ARCMT=OFF \
        -DCLANG_ENABLE_STATIC_ANALYZER=OFF \
        -DCLANG_INCLUDE_DOCS=OFF \
        -DCLANG_INCLUDE_TESTS=OFF \
        -DCLANG_BUILD_TOOLS=OFF \
        -DLLVM_INCLUDE_TESTS=OFF \
        -DLLVM_INCLUDE_EXAMPLES=OFF \
        -DLLVM_INCLUDE_BENCHMARKS=OFF \
        -DLLVM_BUILD_TOOLS=OFF \
        -DLLVM_BUILD_UTILS=OFF \
        -DLLVM_BUILD_LLVM_DYLIB=OFF \
        -DLLVM_LINK_LLVM_DYLIB=OFF \
        -DLLVM_ENABLE_ZLIB=OFF \
        -DLLVM_ENABLE_ZSTD=OFF \
        -DLLVM_ENABLE_TERMINFO=OFF \
        -DLLVM_ENABLE_LIBXML2=OFF \
        -DLLVM_ENABLE_THREADS=OFF \
        -DLLVM_ENABLE_BACKTRACES=OFF \
        -DLLVM_ENABLE_CRASH_OVERRIDES=OFF \
        -DLLVM_ENABLE_ASSERTIONS=OFF \
        -DLLVM_TABLEGEN="$SYSTEM_TBLGEN" \
        -DLLVM_HOST_TRIPLE=wasm32-unknown-emscripten
fi

# Only build the static-library components our backend + driver
# actually reference. The full `ninja` target also tries to build
# llvm-config etc.; we don't need them and they need extra emcc
# linker flags to succeed.
#
# LLVM_* components deduced from llvm/CMakeLists.txt +
# tools/llvm-mov-llc/CMakeLists.txt LINK_COMPONENTS lists in ../llvm-mov/.
# clang* components are clangDriver + clangFrontend + their transitive
# deps — covered by the convenience target `clang-cpp` which links
# everything the standalone clang driver needs.
#
# The `clang-resource-headers` target stages the resource-dir headers
# (stdarg.h etc.) under build/llvm-wasm/lib/clang/<ver>/include/ so
# scripts/build-wasm-clang.sh can `--embed-file` them into clang.wasm.
COMPONENTS=(
    LLVMAnalysis
    LLVMAsmPrinter
    LLVMBitReader
    LLVMBitWriter
    LLVMCodeGen
    LLVMCodeGenTypes
    LLVMCore
    LLVMIRReader
    LLVMMC
    LLVMMCDisassembler
    LLVMMCParser
    LLVMObject
    LLVMOption
    LLVMRemarks
    LLVMScalarOpts
    LLVMSelectionDAG
    LLVMSupport
    LLVMTarget
    LLVMTextAPI
    LLVMTransformUtils
    # clang static libs needed by the standalone driver. clangDriver +
    # clangFrontend pull the rest transitively via cmake's link graph.
    clangDriver
    clangFrontend
    clangFrontendTool
    clangCodeGen
    clangSerialization
    clangSema
    clangParse
    clangLex
    clangBasic
    clang-resource-headers
)

ninja -C "$build" "${COMPONENTS[@]}" 2>&1 | tee "$build/build.log"

echo "wasm-LLVM + clang static libs built: $build"
