#!/usr/bin/env bash
# Stage ../../dist/movie86/ for Cloudflare Pages. Sibling subproject
# is movfuscator-wasm/scripts/stage-deploy.sh — both write into
# the repo-root dist/, and the per-subproject scripts don't clobber
# each other (each only touches its own subdir).
#
# `here` is movie86/wasm/, `root` is the repo root (two levels up).

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
root="$(cd "$here/../.." && pwd)"
dist="$root/dist"
sub="$dist/movie86"

required=(
    "$here/index.html"
    "$here/movie86.mjs"
    "$here/build/browser/movie86_wasm_bg.wasm"
    "$here/build/browser/movie86_wasm.js"
)
for p in "${required[@]}"; do
    if [ ! -e "$p" ]; then
        echo "missing: $p" >&2
        echo "run: make build-wasm" >&2
        exit 1
    fi
done

# Wipe just our own subdir so re-runs replace stale artifacts without
# touching ../dist/movfuscator-wasm/ alongside us. (Don't nuke $dist
# itself — that's owned by movfuscator-wasm/scripts/stage-deploy.sh.)
rm -rf "$sub"
mkdir -p "$sub/build/browser"

cp "$here/index.html"   "$sub/"
cp "$here/movie86.mjs"  "$sub/"

cp "$here/build/browser/movie86_wasm_bg.wasm" \
   "$here/build/browser/movie86_wasm.js" \
   "$here/build/browser/package.json" \
   "$sub/build/browser/"

# Example fixtures so the demo has something to run without the user
# having to upload a real movfuscator binary first.
if [ -d "$here/examples" ]; then
    cp -r "$here/examples" "$sub/examples"
fi

bytes=$(du -sb "$sub" | cut -f1)
files=$(find "$sub" -type f | wc -l)
echo "staged $files files / $(numfmt --to=iec --suffix=B "$bytes") into $sub"
