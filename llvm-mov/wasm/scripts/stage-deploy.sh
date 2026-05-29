#!/usr/bin/env bash
# Assemble the static deploy tree under ../../dist/llvm-mov/ ready for
# Cloudflare Pages. Same shape as
# ../../movfuscator-wasm/scripts/stage-deploy.sh: the source tree layout
# matches the served URL layout so the wrapper's relative imports
# (./build/llvm-mov-llc.js) resolve identically in dev (make serve) and
# on the deployed host.
#
# Note on the path: we live at `llvm-mov/wasm/` in the source tree, but
# the deploy lands at `dist/llvm-mov/` — the wasm/ segment is a build
# detail, not something we want in the URL.
#
# clang.wasm chunk carve-out: at ~76 MiB it busts Cloudflare Pages'
# 25 MiB per-file limit, so build-wasm-clang.sh splits it into
# ≤24 MiB chunks (clang.wasm.part-0..N). We stage the chunks instead
# of the single file and tell the wrapper how many there are via
# CLANG_WASM_CHUNKS in wasm-config.js; llvm-mov.mjs then parallel-
# fetches and concatenates them client-side and hands the bytes to
# Emscripten via `Module.wasmBinary`. No external hosting, no CORS,
# all same-origin.
#
# Layout produced:
#   dist/
#     index.html                       (top-level landing page; refreshed
#                                       only if dist/ doesn't already
#                                       have one from a sibling deploy)
#     llvm-mov/
#       index.html                     (demo)
#       llvm-mov.mjs, llvm-mov.d.ts, wasm-config.js  (with CHUNKS injected)
#       build/llvm-mov-llc.{js,wasm}
#       build/clang.js                 (the small Emscripten loader)
#       build/clang.wasm.part-0..N     (chunks; client merges before init)
#       build/package.json             ({"type":"module"} so the emcc ESM
#                                       loader is parsed correctly)

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
# Two levels up from llvm-mov/wasm/scripts/ → repo root.
root="$(cd "$here/../.." && pwd)"
dist="$root/dist"
sub="$dist/llvm-mov"

required=(
    "$here/llvm-mov.mjs" "$here/llvm-mov.d.ts" "$here/index.html"
    "$here/wasm-config.js"
    "$here/build/llvm-mov-llc.js" "$here/build/llvm-mov-llc.wasm"
    "$here/build/clang.js"
    "$here/build/package.json"
)
for p in "${required[@]}"; do
    if [ ! -e "$p" ]; then
        echo "missing: $p" >&2
        echo "run: make build" >&2
        exit 1
    fi
done

# Locate the clang.wasm chunks. build-wasm-clang.sh produces them
# alongside the single file; if they're missing, fail before staging
# (a partial deploy with no chunks would silently use the wasm-config
# default and 404 on the client side).
chunks=("$here"/build/clang.wasm.part-*)
if [ ! -e "${chunks[0]}" ]; then
    echo "missing: $here/build/clang.wasm.part-*" >&2
    echo "run: make build-wasm-clang (which splits clang.wasm into chunks)" >&2
    exit 1
fi
chunk_count=${#chunks[@]}

# Wipe the previous staging so leftover artefacts from older runs
# don't sneak into the deploy. CI checkouts are clean already; this
# matters for local repro of the deploy contents.
rm -rf "$sub"
mkdir -p "$sub/build"

# Top-level index.html — only refresh if the source tree's version is
# newer or absent, so a parallel `movfuscator-wasm/scripts/stage-deploy.sh`
# run doesn't overwrite a hand-edited landing page.
cp -u "$root/index.html" "$dist/index.html"

cp "$here/index.html"       "$sub/"
cp "$here/llvm-mov.mjs"     "$sub/"
cp "$here/llvm-mov.d.ts"    "$sub/"
cp "$here/wasm-config.js"   "$sub/"

cp "$here/build/llvm-mov-llc.js"   \
   "$here/build/llvm-mov-llc.wasm" \
   "$here/build/clang.js"          \
   "$here/build/package.json"      \
   "$sub/build/"

# Stage the chunks; clang.wasm (the unsplit version) is deliberately
# NOT copied — CF Pages would reject it for being over the 25 MiB
# per-file limit.
cp "$here"/build/clang.wasm.part-* "$sub/build/"

# Tell the wrapper how many chunks to fetch by sed'ing the const value
# in the staged wasm-config.js. The source stays at `null` so local dev
# keeps using the single clang.wasm.
sed -i "s|^export const CLANG_WASM_CHUNKS = null;|export const CLANG_WASM_CHUNKS = $chunk_count;|" \
    "$sub/wasm-config.js"
if ! grep -q "CLANG_WASM_CHUNKS = $chunk_count;" "$sub/wasm-config.js"; then
    echo "wasm-config.js placeholder substitution failed" >&2
    exit 1
fi

bytes=$(du -sb "$sub" | cut -f1)
files=$(find "$sub" -type f | wc -l)
echo "staged $files files ($chunk_count clang chunks) / $(numfmt --to=iec --suffix=B "$bytes") into $sub"
