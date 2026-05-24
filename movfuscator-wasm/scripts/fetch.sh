#!/usr/bin/env bash
# Fetch all upstream sources at pinned versions, apply local patches.
# Idempotent: re-runs reset to the pin and re-patch.

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$here/vendor"

###############################################################################
# movfuscator (LCC + mov backend) — used by Phase A/B
###############################################################################
vendor="$here/vendor/movfuscator"

# Last commit on xoreaxeaxeax/movfuscator master (2020-02-12 ea37dae).
MOVFUSCATOR_SHA="ea37dae93fbcd93f642c71a53878da588bd7ddb4"
MOVFUSCATOR_URL="https://github.com/xoreaxeaxeax/movfuscator"

if [ ! -d "$vendor/.git" ]; then
    git clone "$MOVFUSCATOR_URL" "$vendor"
fi

cd "$vendor"
git fetch --quiet origin
git reset --hard "$MOVFUSCATOR_SHA"
git clean -fdx

for p in "$here"/patches/*.patch; do
    [ -e "$p" ] || continue
    echo "applying $(basename "$p")"
    git apply --whitespace=nowarn "$p"
done

echo "fetched movfuscator pinned at $MOVFUSCATOR_SHA"

###############################################################################
# binutils (gas) — used by Phase C
###############################################################################
binutils_dir="$here/vendor/binutils-2.44"
binutils_tarball="$here/vendor/binutils-2.44.tar.xz"
BINUTILS_URL="https://ftp.gnu.org/gnu/binutils/binutils-2.44.tar.xz"
BINUTILS_SHA256="ce2017e059d63e67ddb9240e9d4ec49c2893605035cd60e92ad53177f4377237"

if [ ! -f "$binutils_tarball" ]; then
    echo "downloading $(basename "$binutils_tarball")"
    curl -fL -o "$binutils_tarball.tmp" "$BINUTILS_URL"
    mv "$binutils_tarball.tmp" "$binutils_tarball"
fi

actual_sha=$(sha256sum "$binutils_tarball" | cut -d' ' -f1)
if [ "$actual_sha" != "$BINUTILS_SHA256" ]; then
    echo "binutils sha256 mismatch: expected $BINUTILS_SHA256, got $actual_sha" >&2
    exit 1
fi

# Re-extract so applied patches are clean
rm -rf "$binutils_dir"
tar -xJf "$binutils_tarball" -C "$here/vendor"

cd "$binutils_dir"
for p in "$here"/patches/binutils-2.44/*.patch; do
    [ -e "$p" ] || continue
    echo "applying $(basename "$p")"
    patch -p1 --quiet < "$p"
done

echo "fetched binutils 2.44 (sha256 ok, patches applied)"
