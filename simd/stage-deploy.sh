#!/usr/bin/env bash
# Stage SIMD86 into ../dist/simd/ for Cloudflare Pages.
#
# Layout produced:
#   dist/simd/
#     index.html                 (/simd/ → redirect to the deck for now)
#     simd.mjs                   (deck runtime; imports /movie86/movie86.mjs)
#     fzstd.mjs                  (in-browser zstd decoder, for the deck)
#     kvm2026-kansai/
#       index.html               (deck viewer: slide ⇿ movie86 side-by-side)
#       deck.elf.zst             (the mov-only flipbook, zstd-compressed)
#       acceleration-boost.png   (the boost button image)
#
# The deck.elf is large uncompressed (a 1280x720 deck is ~160 MB of raw
# RGBA) but zstd-compresses ~50x because slides are mostly flat colour,
# so we ship ONLY `deck.elf.zst` (~few MB). It carries Content-Encoding:
# zstd (see _headers below) so modern browsers decode it for free at the
# network layer; others fall back to the bundled fzstd.mjs. simd.mjs's
# fetchDeck handles both, and falls back to a plain deck.elf for local
# `make serve` (which serves neither _headers nor the .zst).
#
# Like the sibling subprojects' stage scripts this does NOT clear the
# parent dist/ — movfuscator-wasm's stage step runs first (rm -rf dist/),
# then movie86 / llvm-mov / explorer / simd each add their namespace on
# top. Don't reorder: simd imports /movie86/movie86.mjs at runtime, so
# movie86 must be staged too (it is, earlier in the same deploy job).

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
cp "${here}/index.html"                            "${dest}/index.html"
cp "${here}/simd.mjs"                              "${dest}/simd.mjs"
cp "${here}/kvm2026-kansai/index.html"             "${dest}/kvm2026-kansai/index.html"
cp "${here}/kvm2026-kansai/acceleration-boost.png" "${dest}/kvm2026-kansai/acceleration-boost.png"

# zstd-compress the deck. -19 gets the ~50x ratio; the deck is built
# once per deploy so the compression time is fine.
zstd -q -19 -f "${deck}" -o "${dest}/kvm2026-kansai/deck.elf.zst"

# fzstd: the in-browser zstd decoder simd.mjs imports as ./fzstd.mjs.
# Reuse the copy llvm-mov already vendors (its stage-deploy stages it
# too); falling back to its node_modules if the staged one isn't there.
fzstd=""
for cand in \
    "${repo_root}/dist/llvm-mov/build/fzstd.mjs" \
    "${repo_root}/llvm-mov/wasm/node_modules/fzstd/esm/index.mjs"; do
    [[ -f "${cand}" ]] && { fzstd="${cand}"; break; }
done
if [[ -z "${fzstd}" ]]; then
    echo "stage-deploy: fzstd.mjs not found (build llvm-mov/wasm first, or" \
         "npm i fzstd there)" >&2
    exit 1
fi
# simd.mjs imports './fzstd.mjs' relative to itself (dist/simd/).
cp "${fzstd}" "${dest}/fzstd.mjs"

# _headers: Cloudflare Pages reads ONE _headers at the dist root. llvm-mov
# writes it first (earlier stage step); we APPEND our /simd/ rules so the
# two don't clobber each other (its CLAUDE.md note asks for exactly this).
# Content-Encoding: zstd lights up native decompression; the name is fixed
# (not content-hashed) so use a short max-age + revalidation rather than
# immutable — the deck changes across deploys.
hdr="${repo_root}/dist/_headers"
cat >> "${hdr}" <<'EOF'
/simd/kvm2026-kansai/deck.elf.zst
  Content-Encoding: zstd
  Cache-Control: public, max-age=3600
EOF

size=$(du -sh "${dest}" 2>/dev/null | awk '{print $1}')
files=$(find "${dest}" -type f | wc -l)
zsize=$(stat -c %s "${dest}/kvm2026-kansai/deck.elf.zst")
echo "stage-deploy: ${dest} (${size}, ${files} files; deck.elf.zst $(numfmt --to=iec --suffix=B "${zsize}"))"
