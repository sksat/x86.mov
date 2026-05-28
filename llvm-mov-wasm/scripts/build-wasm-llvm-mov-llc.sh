#!/usr/bin/env bash
# Build the Mov backend + llvm-mov-llc driver as Emscripten wasm,
# linking against the Emscripten LLVM static libs from
# scripts/build-wasm-llvm.sh.
#
# Output:
#   build/llvm-mov-wasm/bin/llvm-mov-llc.{js,wasm}
#
# We point cmake at ../llvm-mov/CMakeLists.txt so the wasm and native
# builds share the same backend source tree — every backend edit lands
# in ../llvm-mov/ and is picked up here automatically.

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
backend_src="$(cd "$here/../llvm-mov" && pwd)"
llvm_build="$here/build/llvm-wasm"
build="$here/build/llvm-mov-wasm"
out="$here/build"

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

SYSTEM_TBLGEN="${LLVM_TABLEGEN:-/usr/lib/llvm-22/bin/llvm-tblgen}"
if [ ! -x "$SYSTEM_TBLGEN" ]; then
    echo "system llvm-tblgen missing at $SYSTEM_TBLGEN" >&2
    exit 1
fi

mkdir -p "$build"

# Link flags for the driver executable.
# - MODULARIZE+EXPORT_ES6+EXPORT_NAME: ship a single artifact usable
#   from both node ESM (`import createMovLlc from './llvm-mov-llc.js'`)
#   and the browser, mirroring movfuscator-wasm's browser variant. The
#   wrapper does `await createMovLlc(opts)` then `FS.writeFile` /
#   `callMain` — same shape as ../movfuscator-wasm/movfuscator.mjs.
# - FORCE_FILESYSTEM: keep MEMFS available even though the only code
#   in the wasm reads from FS via callMain's argv (cl::opt strings).
# - INVOKE_RUN=0: don't auto-run main on module load — the wrapper
#   calls `callMain([...])` itself.
# - EXIT_RUNTIME=1: the driver calls exit() at end of main; without
#   this Emscripten leaves the runtime active and the next FS write
#   would land in a stale instance.
# - ALLOW_MEMORY_GROWTH + INITIAL_MEMORY=128MB: LLVM allocates
#   aggressively (DAG-ISel scratch, MachineFunction analyses); 128 MB
#   startup heap avoids first-compile growth thrash.
# - STACK_SIZE=8MB: LLVM recursion depth on bigger examples blows the
#   default 64 KB wasm stack (DAGCombiner is the usual culprit).
# - EXPORTED_RUNTIME_METHODS=callMain,FS: the only Emscripten runtime
#   APIs the wrapper touches; everything else can be DCEed.
EMCC_LINK_FLAGS=(
    "-sMODULARIZE=1"
    "-sEXPORT_ES6=1"
    "-sEXPORT_NAME=createMovLlc"
    "-sENVIRONMENT=web,node,worker"
    "-sFORCE_FILESYSTEM=1"
    "-sINVOKE_RUN=0"
    "-sEXIT_RUNTIME=1"
    "-sALLOW_MEMORY_GROWTH=1"
    "-sINITIAL_MEMORY=128MB"
    "-sSTACK_SIZE=8MB"
    "-sEXPORTED_RUNTIME_METHODS=['callMain','FS']"
)

# Idempotent configure.
if [ ! -f "$build/build.ninja" ]; then
    EMCC_LINK_FLAGS_STR="${EMCC_LINK_FLAGS[*]}"
    emcmake cmake -S "$backend_src" -B "$build" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLVM_DIR="$llvm_build/lib/cmake/llvm" \
        -DLLVM_TABLEGEN_EXE="$SYSTEM_TBLGEN" \
        -DCMAKE_EXE_LINKER_FLAGS="$EMCC_LINK_FLAGS_STR"
fi

ninja -C "$build" llvm-mov-llc 2>&1 | tee "$build/build.log"

# Stage the artifacts under build/ alongside the wrapper, mirroring
# movfuscator-wasm's layout (build/cpp.{js,wasm} etc.).
# Emcmake-built executables land at `bin/<target>.js` (+ `.wasm`)
# directly — there's no separate extensionless launcher like a native
# build would have.
mkdir -p "$out"
cp "$build/bin/llvm-mov-llc.js"   "$out/llvm-mov-llc.js"
cp "$build/bin/llvm-mov-llc.wasm" "$out/llvm-mov-llc.wasm"

# Tell Node to treat build/ as an ESM directory. Without this the
# `import createMovLlc from './build/llvm-mov-llc.js'` in our wrapper
# trips the "Cannot use import statement outside a module" error
# because Node defaults to CommonJS for .js when there's no closer
# package.json.
echo '{"type":"module"}' > "$out/package.json"

# Emscripten bakes the wasm filename into the .js (matches the .wasm
# basename produced by emcc). Since we kept the basename
# (llvm-mov-llc.wasm) end-to-end, no rename sed is needed (unlike
# binutils' as-new.wasm/ld-new.wasm in movfuscator-wasm).

echo "wasm llvm-mov-llc build complete:"
ls -la "$out"/llvm-mov-llc.{js,wasm}
