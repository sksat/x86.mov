#!/usr/bin/env bash
# Assemble the static deploy tree under ../dist/ ready for Cloudflare Pages.
#
# Layout produced:
#   dist/
#     index.html                       (repo root landing page)
#     movfuscator-wasm/
#       index.html, md5.{c,h}          (demo)
#       movfuscator.mjs, movfuscator.d.ts
#       build/browser/{cpp,rcc,as,ld}.{js,wasm}
#       build/browser/package.json     ({"type":"module"} so emcc ESM loaders parse)
#       lib/                           (link-input bundle)
#
# Layout matches the source tree (no path rewriting needed) — the wrapper
# at movfuscator-wasm/movfuscator.mjs imports ./build/browser/cpp.js and
# ./lib/, which resolve correctly both in dev (make serve) and on the
# deployed host.

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
root="$(cd "$here/.." && pwd)"
dist="$root/dist"
sub="$dist/movfuscator-wasm"

required=(
    "$here/movfuscator.mjs" "$here/movfuscator.d.ts"
    "$here/index.html" "$here/md5.c" "$here/md5.h"
    "$here/build/browser/cpp.wasm" "$here/build/browser/rcc.wasm"
    "$here/build/browser/as.wasm"  "$here/build/browser/ld.wasm"
    "$here/lib/lib32/libc.so.6"
)
for p in "${required[@]}"; do
    if [ ! -e "$p" ]; then
        echo "missing: $p" >&2
        echo "run: make build-wasm-browser build-wasm-as-browser build-wasm-ld-browser stage-link-libs" >&2
        exit 1
    fi
done

rm -rf "$dist"
mkdir -p "$sub/build/browser"

cp "$root/index.html"           "$dist/index.html"

cp "$here/index.html"           "$sub/"
cp "$here/md5.c" "$here/md5.h"  "$sub/"
cp "$here/movfuscator.mjs"      "$sub/"
cp "$here/movfuscator.d.ts"     "$sub/"

cp "$here/build/browser"/cpp.js "$here/build/browser"/cpp.wasm \
   "$here/build/browser"/rcc.js "$here/build/browser"/rcc.wasm \
   "$here/build/browser"/as.js  "$here/build/browser"/as.wasm \
   "$here/build/browser"/ld.js  "$here/build/browser"/ld.wasm \
   "$here/build/browser/package.json" \
   "$sub/build/browser/"

cp -r "$here/lib" "$sub/lib"

bytes=$(du -sb "$dist" | cut -f1)
files=$(find "$dist" -type f | wc -l)
echo "staged $files files / $(numfmt --to=iec --suffix=B "$bytes") into $dist"
