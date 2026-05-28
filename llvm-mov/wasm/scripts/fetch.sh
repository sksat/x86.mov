#!/usr/bin/env bash
# Fetch the LLVM source tree at the pinned tag. Idempotent: re-runs
# reset to the pinned tag and clean local edits.

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$here/vendor"

# Pin to the same minor as the system apt.llvm.org install — the wasm
# LLVM and the system TableGen used during the wasm build have to be
# version-compatible. Bump alongside the host pin when stepping forward.
LLVM_TAG="${LLVM_TAG:-llvmorg-22.1.6}"
LLVM_URL="https://github.com/llvm/llvm-project.git"

vendor="$here/vendor/llvm-project"

if [ ! -d "$vendor/.git" ]; then
    # Shallow clone at the tag — the full history is ~3 GB, the tagged
    # snapshot is ~700 MB which still hurts but is the minimum LLVM
    # cmake actually needs (it pulls cross-component files from runtimes/
    # and cmake/, so a single-subtree sparse-checkout doesn't work).
    git clone --depth 1 --branch "$LLVM_TAG" "$LLVM_URL" "$vendor"
else
    cd "$vendor"
    # If we're already on the tag, do nothing — saves a network hop
    # on every `make build` from a warm tree.
    current="$(git describe --tags --exact-match HEAD 2>/dev/null || true)"
    if [ "$current" != "$LLVM_TAG" ]; then
        git fetch --depth 1 origin "refs/tags/$LLVM_TAG:refs/tags/$LLVM_TAG"
        git reset --hard "$LLVM_TAG"
        git clean -fdx
    fi
fi

# Patches go under patches/ and apply on top — empty initially.
if [ -d "$here/patches" ]; then
    cd "$vendor"
    for p in "$here"/patches/*.patch; do
        [ -e "$p" ] || continue
        echo "applying $(basename "$p")"
        git apply --whitespace=nowarn "$p"
    done
fi

echo "fetched llvm-project pinned at $LLVM_TAG"
