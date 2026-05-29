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
# clang.wasm zstd carve-out: at ~80 MiB the uncompressed wasm busts
# Cloudflare Pages' 25 MiB/file limit, so the deploy ships
# `clang.wasm-{hash}.zst` (~14 MiB) instead. The wrapper imports
# `./build/fzstd.mjs` (a 24 KB pure-JS zstd decoder vendored from
# the npm `fzstd` package) to decompress in-browser, side-stepping
# the patchy native `Content-Encoding: zstd` support. The hash in
# the filename means a binary bump rotates the URL and the immutable
# cache (`Cache-Control: max-age=31536000, immutable`) flushes
# naturally.
#
# Layout produced:
#   dist/
#     index.html                            (top-level landing page)
#     _headers                              (immutable cache for hashed artefacts)
#     llvm-mov/
#       index.html                          (demo)
#       llvm-mov.mjs, llvm-mov.d.ts, wasm-config.js
#       build/llvm-mov-llc.{js,wasm}
#       build/clang.js                      (small Emscripten loader)
#       build/clang.wasm-{hash}.zst         (zstd-compressed clang.wasm)
#       build/fzstd.mjs                     (single-file zstd decoder)
#       build/package.json                  ({"type":"module"})

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
# Two levels up from llvm-mov/wasm/scripts/ → repo root.
root="$(cd "$here/../.." && pwd)"
dist="$root/dist"
sub="$dist/llvm-mov"

fzstd_src="$here/node_modules/fzstd/esm/index.mjs"
required=(
    "$here/llvm-mov.mjs" "$here/llvm-mov.d.ts" "$here/index.html"
    "$here/wasm-config.js"
    "$here/build/llvm-mov-llc.js" "$here/build/llvm-mov-llc.wasm"
    "$here/build/clang.js"
    "$here/build/clang.wasm.zst" "$here/build/clang.wasm.hash"
    "$here/build/package.json"
    "$fzstd_src"
)
for p in "${required[@]}"; do
    if [ ! -e "$p" ]; then
        echo "missing: $p" >&2
        echo "run: make build" >&2
        exit 1
    fi
done

# Wipe the previous staging so leftover artefacts from older runs
# (e.g. the old clang.wasm.part-* chunks) don't sneak into the deploy.
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

# Read the content-hash build-wasm-clang.sh stamped on clang.wasm and
# use it as the zst filename suffix. The wrapper composes the URL
# using the same hash from wasm-config.js, the browser caches it
# immutably, and a binary bump rotates the URL so a stale cache can't
# pin the user to an old binary.
hash="$(tr -d ' \n' < "$here/build/clang.wasm.hash")"
case "$hash" in
    [0-9a-f]*) ;;
    *)
        echo "clang.wasm.hash content $hash is not a hex digest" >&2
        exit 1 ;;
esac
cp "$here/build/clang.wasm.zst" "$sub/build/clang.wasm-${hash}.zst"
# fzstd is the in-browser zstd decoder. The npm package's `esm/` build
# is a single ~24 KB self-contained ES module — perfect to drop in
# next to clang.js so the wrapper's `import('./build/fzstd.mjs')`
# resolves with no bundler step.
cp "$fzstd_src" "$sub/build/fzstd.mjs"

# Tell the wrapper which version of clang.wasm to ask for by sed'ing
# the const value in the staged wasm-config.js. Source stays at `null`
# so local dev keeps using the uncompressed single clang.wasm.
sed -i "s|^export const CLANG_WASM_VERSION = null;|export const CLANG_WASM_VERSION = '$hash';|" \
    "$sub/wasm-config.js"
if ! grep -q "CLANG_WASM_VERSION = '$hash';" "$sub/wasm-config.js"; then
    echo "wasm-config.js placeholder substitution failed" >&2
    exit 1
fi

# Cloudflare Pages `_headers` only takes one file per project at the
# dist root. We're the first subproject to use it; if a sibling later
# needs its own rules, refactor into an append-and-dedupe shape.
#
# The pattern uses a single trailing `*` (CF Pages' matcher doesn't
# honour mid-string wildcards) and anchors on the `clang.wasm-` prefix
# that only the hashed zst appears under.
#
# `Content-Encoding: zstd` lights up the native-decompression fast
# path on modern Chromium/Firefox/Edge. Browsers without native zstd
# (Safari today) pass the raw bytes through to the JS layer, where
# the wrapper's magic-byte check routes them to fzstd instead — see
# `fetchClangWasm` in llvm-mov.mjs. The wrapper handles both shapes
# without any UA sniffing.
#
# `Content-Type: application/wasm` is wrong for the on-wire bytes
# (which are zstd) but right for what we hand Emscripten after
# decompression. Browsers tolerate the mismatch on regular fetches;
# the streaming wasm compile path doesn't run because we feed bytes
# via `Module.wasmBinary` rather than letting Emscripten fetch.
#
# `Cache-Control: immutable` pairs with the hashed filename for free
# cross-load caching.
cat > "$dist/_headers" <<'EOF'
/llvm-mov/build/clang.wasm-*
  Content-Encoding: zstd
  Content-Type: application/wasm
  Cache-Control: public, max-age=31536000, immutable
EOF

bytes=$(du -sb "$sub" | cut -f1)
files=$(find "$sub" -type f | wc -l)
echo "staged $files files (clang.wasm.zst @ $hash) / $(numfmt --to=iec --suffix=B "$bytes") into $sub"
