#!/usr/bin/env bash
# Stage the built Vite bundle into ../dist/explorer/.
#
# Mirrors movie86/wasm/scripts/stage-deploy.sh:
#   - relative to the subproject root (explorer/)
#   - writes into <repo>/dist/explorer/
#   - does NOT clear the parent dist/ — movfuscator-wasm's stage step
#     does that first in the deploy workflow.
#
# Order in .github/workflows/deploy.yaml:
#   movfuscator-wasm stage-deploy (rm -rf dist/ + repopulate)
#   movie86/wasm stage-deploy     (writes dist/movie86/)
#   llvm-mov/wasm stage-deploy    (writes dist/llvm-mov/)
#   explorer stage-deploy         (writes dist/explorer/)
# Don't reorder.

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
repo_root="$(cd "${here}/.." && pwd)"
dest="${repo_root}/dist/explorer"

mkdir -p "${dest}"
# Vite already wrote to ../dist/explorer via vite.config.ts. If the
# user ran `vite build` with a different outDir (or skipped it), bail
# loudly rather than silently shipping an empty path.
if [[ ! -d "${here}/../dist/explorer" ]]; then
    echo "stage-deploy: no built bundle at ${here}/../dist/explorer — run 'make build' first" >&2
    exit 1
fi

# The Vite build already populated the dest directory via vite.config.ts
# (build.outDir: '../dist/explorer'). Nothing else to copy — just sanity
# check that the entry HTML landed and print a short summary.
ls "${dest}/index.html" >/dev/null

size=$(du -sh "${dest}" 2>/dev/null | awk '{print $1}')
files=$(find "${dest}" -type f | wc -l)
echo "stage-deploy: ${dest} (${size}, ${files} files)"
