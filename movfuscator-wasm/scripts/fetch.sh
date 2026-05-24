#!/usr/bin/env bash
# Clone upstream movfuscator at the pinned SHA and apply local patches.
# Idempotent: re-running on an existing tree resets to the pin and re-patches.

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
vendor="$here/vendor/movfuscator"

# Last commit on xoreaxeaxeax/movfuscator master (2020-02-12 ea37dae).
# Pinned for build reproducibility.
MOVFUSCATOR_SHA="ea37dae93fbcd93f642c71a53878da588bd7ddb4"
MOVFUSCATOR_URL="https://github.com/xoreaxeaxeax/movfuscator"

mkdir -p "$here/vendor"

if [ ! -d "$vendor/.git" ]; then
    git clone "$MOVFUSCATOR_URL" "$vendor"
fi

cd "$vendor"
git fetch --quiet origin
git reset --hard "$MOVFUSCATOR_SHA"
git clean -fdx

# Apply local patches in lexical order.
for p in "$here"/patches/*.patch; do
    [ -e "$p" ] || continue
    echo "applying $(basename "$p")"
    git apply --whitespace=nowarn "$p"
done

echo "fetched upstream pinned at $MOVFUSCATOR_SHA"
