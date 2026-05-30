#!/usr/bin/env bash
# Stage SIMD86 into ../dist/simd/ for Cloudflare Pages.
#
# Layout produced:
#   dist/simd/
#     index.html                 (/simd/ → redirect to the deck for now)
#     simd.mjs                   (deck runtime; imports /movie86/movie86.mjs)
#     kvm2026-kansai/
#       index.html               (deck viewer: slide ⇿ movie86 side-by-side)
#       deck.elf                 (the mov-only flipbook)
#
# Like the sibling subprojects' stage scripts this does NOT clear the
# parent dist/ — movfuscator-wasm's stage step runs first (rm -rf dist/
# + repopulate + copy the root index.html), then movie86 / llvm-mov /
# explorer / simd each add their namespace on top. Don't reorder: simd
# imports /movie86/movie86.mjs at runtime, so movie86 must be staged too
# (it is, earlier in the same deploy job).

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${here}/.." && pwd)"
dest="${repo_root}/dist/simd"

deck="${here}/kvm2026-kansai/deck.elf"
if [[ ! -f "${deck}" ]]; then
    echo "stage-deploy: missing ${deck} — run ./build-deck.sh first" >&2
    exit 1
fi

mkdir -p "${dest}/kvm2026-kansai"
cp "${here}/index.html"                  "${dest}/index.html"
cp "${here}/simd.mjs"                    "${dest}/simd.mjs"
cp "${here}/kvm2026-kansai/index.html"   "${dest}/kvm2026-kansai/index.html"
cp "${deck}"                             "${dest}/kvm2026-kansai/deck.elf"

size=$(du -sh "${dest}" 2>/dev/null | awk '{print $1}')
files=$(find "${dest}" -type f | wc -l)
echo "stage-deploy: ${dest} (${size}, ${files} files)"
