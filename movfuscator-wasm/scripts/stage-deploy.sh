#!/usr/bin/env bash
# Assemble the static deploy tree under ../dist/ ready for Cloudflare Pages.
#
# Layout produced:
#   dist/
#     index.html                       (repo root landing page)
#     movfuscator-wasm/
#       index.html, md5.c, md5.h       (from movfuscator-wasm/web/)
#       movfuscator.mjs                (import paths rewritten — flat layout)
#       cpp.{js,wasm}, rcc.{js,wasm}   (from build/browser/)
#       as.{js,wasm}, ld.{js,wasm}
#       lib/                           (from web/lib/, the link-input bundle)
#
# The dev layout under movfuscator-wasm/web is intentionally untouched —
# movfuscator.mjs there still uses ../build/browser/cpp.js etc. so `make serve`
# keeps working; we only rewrite during deploy staging.

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
root="$(cd "$here/.." && pwd)"
dist="$root/dist"
sub="$dist/movfuscator-wasm"

build_browser="$here/build/browser"
web="$here/web"
web_lib="$here/web/lib"

for p in "$build_browser/cpp.wasm" "$build_browser/rcc.wasm" \
         "$build_browser/as.wasm"  "$build_browser/ld.wasm" \
         "$web/movfuscator.mjs" "$web/index.html" \
         "$web_lib/lib32/libc.so.6"; do
    if [ ! -f "$p" ]; then
        echo "missing: $p" >&2
        echo "run: make build-wasm-browser build-wasm-as-browser build-wasm-ld-browser stage-link-libs" >&2
        exit 1
    fi
done

rm -rf "$dist"
mkdir -p "$sub"

cp "$root/index.html" "$dist/index.html"

cp "$web/index.html" "$sub/index.html"
cp "$web/md5.c"      "$sub/md5.c"
cp "$web/md5.h"      "$sub/md5.h"

cp "$build_browser"/cpp.js   "$build_browser"/cpp.wasm \
   "$build_browser"/rcc.js   "$build_browser"/rcc.wasm \
   "$build_browser"/as.js    "$build_browser"/as.wasm \
   "$build_browser"/ld.js    "$build_browser"/ld.wasm \
   "$sub/"

# Flatten movfuscator.mjs's imports for the deploy layout.
# In dev:  '../build/browser/cpp.js'  →  in dist:  './cpp.js'
sed "s|\.\./build/browser/|./|g" "$web/movfuscator.mjs" > "$sub/movfuscator.mjs"

cp -r "$web_lib" "$sub/lib"

bytes=$(du -sb "$dist" | cut -f1)
files=$(find "$dist" -type f | wc -l)
echo "staged $files files / $(numfmt --to=iec --suffix=B "$bytes") into $dist"
