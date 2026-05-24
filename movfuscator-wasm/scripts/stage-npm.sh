#!/usr/bin/env bash
# Assemble the npm package payload under ./npm-package/.
#
# Layout produced (matches what gets shipped to consumers — flat, no
# build/browser/ prefix, so `import from 'movfuscator-wasm'` and the
# wrapper's `./cpp.js` style imports just work):
#
#   npm-package/
#     package.json                   (copied verbatim)
#     README.md                      (copied verbatim)
#     movfuscator.mjs                (imports rewritten to ./cpp.js etc.)
#     cpp.{js,wasm}, rcc.{js,wasm}
#     as.{js,wasm}, ld.{js,wasm}
#     lib/                           (the link-input bundle)
#
# Smoke test: cd npm-package && node -e "import('./movfuscator.mjs')..."

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
out="$here/npm-package"
build_browser="$here/build/browser"
web="$here/web"
web_lib="$here/web/lib"

for p in "$build_browser/cpp.wasm" "$build_browser/rcc.wasm" \
         "$build_browser/as.wasm"  "$build_browser/ld.wasm" \
         "$web/movfuscator.mjs" \
         "$web_lib/lib32/libc.so.6" "$web_lib/movfuscator/libgcc.a" \
         "$here/package.json"; do
    if [ ! -f "$p" ]; then
        echo "missing: $p" >&2
        echo "run: make build-wasm-browser build-wasm-as-browser build-wasm-ld-browser stage-link-libs" >&2
        exit 1
    fi
done

rm -rf "$out"
mkdir -p "$out"

cp "$here/package.json" "$out/package.json"
[ -f "$here/README.md" ] && cp "$here/README.md" "$out/README.md"

cp "$build_browser"/cpp.js   "$build_browser"/cpp.wasm \
   "$build_browser"/rcc.js   "$build_browser"/rcc.wasm \
   "$build_browser"/as.js    "$build_browser"/as.wasm \
   "$build_browser"/ld.js    "$build_browser"/ld.wasm \
   "$out/"

sed "s|\.\./build/browser/|./|g" "$web/movfuscator.mjs" > "$out/movfuscator.mjs"

cp -r "$web_lib" "$out/lib"

bytes=$(du -sb "$out" | cut -f1)
files=$(find "$out" -type f | wc -l)
echo "staged $files files / $(numfmt --to=iec --suffix=B "$bytes") into $out"
echo "tip: 'cd $out && npm pack' to inspect what would be published"
