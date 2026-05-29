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
# per-file limit. We host it on a GitHub Release instead. The deploy
# workflow sets `$CLANG_WASM_URL` to the release asset URL and this
# script substitutes it into wasm-config.js so the wrapper's
# `locateFile` fetches the .wasm from there. clang.wasm itself is
# *not* copied into dist/. For local dev/tests `$CLANG_WASM_URL` is
# unset and llvm-mov.mjs falls back to `./build/clang.wasm`.
#
# Layout produced:
#   dist/
#     index.html                       (top-level landing page; refreshed
#                                       only if dist/ doesn't already
#                                       have one from a sibling deploy)
#     llvm-mov/
#       index.html                     (demo)
#       llvm-mov.mjs, llvm-mov.d.ts, wasm-config.js
#       build/llvm-mov-llc.{js,wasm}
#       build/clang.js                 (small Emscripten loader; the
#                                       .wasm is fetched from release)
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

# Wipe the previous staging so leftover artefacts from older runs
# (e.g. a clang.wasm staged before we moved it to GitHub Releases)
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

# Inject the GitHub Release URL when the deploy workflow provided one.
# The substitution targets only the `null` placeholder so re-running on
# a tree where the URL was already substituted is a no-op.
if [ -n "${CLANG_WASM_URL:-}" ]; then
    # URL safety: reject anything that isn't an https:// URL pointing at a
    # known asset host. The substitution lands inside a JS string literal,
    # so a malformed value (e.g. one containing a single quote) would
    # corrupt wasm-config.js. We also use a non-/ sed delimiter to avoid
    # escaping the URL path.
    case "$CLANG_WASM_URL" in
        https://github.com/*/releases/download/*/clang.wasm) ;;
        *)
            echo "refusing to inject CLANG_WASM_URL: $CLANG_WASM_URL" >&2
            echo "expected https://github.com/.../releases/download/.../clang.wasm" >&2
            exit 1 ;;
    esac
    sed -i "s|^export const CLANG_WASM_URL = null;|export const CLANG_WASM_URL = '$CLANG_WASM_URL';|" \
        "$sub/wasm-config.js"
    if ! grep -q "CLANG_WASM_URL = '$CLANG_WASM_URL';" "$sub/wasm-config.js"; then
        echo "wasm-config.js placeholder substitution failed" >&2
        exit 1
    fi
fi

bytes=$(du -sb "$sub" | cut -f1)
files=$(find "$sub" -type f | wc -l)
echo "staged $files files / $(numfmt --to=iec --suffix=B "$bytes") into $sub"
