#!/usr/bin/env bash
# Build LLVM 22.1.x as Emscripten static libs.
#
# Output:
#   build/llvm-wasm/  — Ninja build dir with libLLVM*.a, lib/cmake/llvm/
#                       (the artifact our backend build's
#                       find_package(LLVM REQUIRED CONFIG) points at)
#
# This is the slow step (~30–90 minutes on a 4-core machine). The
# subsequent backend build is fast in comparison.
#
# Quirks worth knowing:
# - LLVM_TARGETS_TO_BUILD is intentionally empty. The Mov target is the
#   only one we use and it's registered out-of-tree by the backend libs.
#   Building X86 / AArch64 / etc. in-tree would balloon the wasm by
#   tens of MB for code that's never reached.
# - LLVM_TABLEGEN points at the system llvm-tblgen so TableGen
#   invocations don't have to round-trip through Node + wasm. Same
#   pattern movfuscator-wasm uses for binutils' chew.
# - LLVM_INCLUDE_{TESTS,EXAMPLES,BENCHMARKS} are all OFF to skip the
#   gtest/google-benchmark builds Emscripten would otherwise drag in.
# - LLVM_BUILD_TOOLS=OFF / LLVM_BUILD_UTILS=OFF — we don't need llc,
#   opt, etc. as wasm; our llvm-mov-llc driver is the only tool that
#   gets emcc-linked.

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

# Idempotent: skip the configure step if it already ran. Re-running
# emcmake on a configured build dir is harmless but cmake re-walks the
# whole config which is ~30 s of pointless work on warm builds.
if [ ! -f "$build/build.ninja" ]; then
    emcmake cmake -S "$src" -B "$build" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLVM_TARGETS_TO_BUILD="" \
        -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD="" \
        -DLLVM_ENABLE_PROJECTS="" \
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
# Set deduced from llvm/CMakeLists.txt + tools/llvm-mov-llc/CMakeLists.txt
# LINK_COMPONENTS lists in ../llvm-mov/.
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
)

ninja -C "$build" "${COMPONENTS[@]}" 2>&1 | tee "$build/build.log"

echo "wasm-LLVM build complete: $build"
