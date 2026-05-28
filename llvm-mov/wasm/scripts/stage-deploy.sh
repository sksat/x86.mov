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
# Layout produced:
#   dist/
#     index.html                       (top-level landing page; refreshed
#                                       only if dist/ doesn't already
#                                       have one from a sibling deploy)
#     llvm-mov/
#       index.html                     (demo)
#       llvm-mov.mjs, llvm-mov.d.ts
#       build/{llvm-mov-llc,clang}.{js,wasm}
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
    "$here/build/llvm-mov-llc.js" "$here/build/llvm-mov-llc.wasm"
    "$here/build/clang.js"        "$here/build/clang.wasm"
    "$here/build/package.json"
)
for p in "${required[@]}"; do
    if [ ! -e "$p" ]; then
        echo "missing: $p" >&2
        echo "run: make build" >&2
        exit 1
    fi
done

mkdir -p "$sub/build"

# Top-level index.html — only refresh if the source tree's version is
# newer or absent, so a parallel `movfuscator-wasm/scripts/stage-deploy.sh`
# run doesn't overwrite a hand-edited landing page.
cp -u "$root/index.html" "$dist/index.html"

cp "$here/index.html"       "$sub/"
cp "$here/llvm-mov.mjs"     "$sub/"
cp "$here/llvm-mov.d.ts"    "$sub/"

cp "$here/build/llvm-mov-llc.js"   \
   "$here/build/llvm-mov-llc.wasm" \
   "$here/build/clang.js"          \
   "$here/build/clang.wasm"        \
   "$here/build/package.json"      \
   "$sub/build/"

bytes=$(du -sb "$sub" | cut -f1)
files=$(find "$sub" -type f | wc -l)
echo "staged $files files / $(numfmt --to=iec --suffix=B "$bytes") into $sub"
