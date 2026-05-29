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
# clang.wasm carve-out: at ~76 MiB it busts Cloudflare Pages' 25 MiB
# per-file limit. We host it on a GitHub Release. A Pages Function
# (functions/clang.wasm.template.js) is installed at
# `dist/functions/llvm-mov/build/clang.wasm.js` which proxies the
# release asset with the CORS headers GitHub doesn't serve. The
# Emscripten loader's default fetch path (`./build/clang.wasm`
# relative to clang.js) hits the function — no wrapper-side override
# needed.
#
# Layout produced:
#   dist/
#     index.html                       (top-level landing page; refreshed
#                                       only if dist/ doesn't already
#                                       have one from a sibling deploy)
#     functions/
#       llvm-mov/build/clang.wasm.js   (Pages Function proxying GH Release)
#     llvm-mov/
#       index.html                     (demo)
#       llvm-mov.mjs, llvm-mov.d.ts, wasm-config.js
#       build/llvm-mov-llc.{js,wasm}
#       build/clang.js                 (small Emscripten loader; the
#                                       .wasm is served by the Function)
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
    "$here/functions/clang.wasm.template.js"
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

# Wipe the previous staging so leftover artefacts from older runs
# (e.g. a clang.wasm staged before we moved it to GitHub Releases)
# don't sneak into the deploy. CI checkouts are clean already; this
# matters for local repro of the deploy contents.
rm -rf "$sub" "$dist/functions/llvm-mov"
mkdir -p "$sub/build" "$dist/functions/llvm-mov/build"

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

# Stage the Pages Function proxy for clang.wasm. The function file
# lives at dist/functions/<URL path>.js, so this lands at
# `/llvm-mov/build/clang.wasm` — exactly where Emscripten's loader
# looks for the .wasm sibling of clang.js.
fn="$dist/functions/llvm-mov/build/clang.wasm.js"
cp "$here/functions/clang.wasm.template.js" "$fn"

# `_routes.json` opts the proxy path explicitly into the Functions
# runtime. Without this, the project's SPA-fallback setting (serving
# `dist/index.html` for any unmatched path) intercepts the request
# before the function gets a chance to run. We only `include` the one
# path we care about; everything else still goes through the default
# (static asset → SPA fallback).
cat > "$dist/_routes.json" <<'EOF'
{
    "version": 1,
    "include": ["/llvm-mov/build/clang.wasm"],
    "exclude": []
}
EOF

if [ -n "${CLANG_WASM_URL:-}" ]; then
    # URL safety: reject anything that isn't an https:// URL pointing at a
    # known asset host. The substitution lands inside a JS string literal,
    # so a malformed value (e.g. one containing a single quote) would
    # corrupt the function source.
    case "$CLANG_WASM_URL" in
        https://github.com/*/releases/download/*/clang.wasm) ;;
        *)
            echo "refusing to inject CLANG_WASM_URL: $CLANG_WASM_URL" >&2
            echo "expected https://github.com/.../releases/download/.../clang.wasm" >&2
            exit 1 ;;
    esac
    # Restrict the substitution to the `const RELEASE_URL = '…'` line
    # so the surrounding doc comments keep mentioning the placeholder
    # name verbatim.
    sed -i "/^const RELEASE_URL/ s|__CLANG_WASM_RELEASE_URL__|$CLANG_WASM_URL|" "$fn"
    if ! grep -q "const RELEASE_URL = '$CLANG_WASM_URL';" "$fn"; then
        echo "Pages Function placeholder substitution failed" >&2
        exit 1
    fi
else
    # No URL — the function will hit the placeholder which makes its
    # fetch fail loudly at runtime. Useful for `make stage-deploy`
    # locally where we just want to see the layout.
    echo "warning: CLANG_WASM_URL not set, clang.wasm proxy will fail at runtime" >&2
fi

bytes=$(du -sb "$sub" "$dist/functions/llvm-mov" 2>/dev/null | awk '{s+=$1} END {print s}')
files=$(find "$sub" "$dist/functions/llvm-mov" -type f 2>/dev/null | wc -l)
echo "staged $files files / $(numfmt --to=iec --suffix=B "$bytes") into $sub + functions"
