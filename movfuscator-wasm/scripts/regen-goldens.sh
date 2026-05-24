#!/usr/bin/env bash
# Regenerate tests/goldens/*.s using the native rcc binary.
# Run after adding a new fixture, after changing the upstream pin, or after
# changing preprocess.sh — all of which can legitimately change goldens.

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
vendor="$here/vendor/movfuscator"
rcc="$vendor/build/rcc"
fixtures="$here/tests/fixtures"
goldens="$here/tests/goldens"

if [ ! -x "$rcc" ]; then
    echo "native rcc missing; run scripts/build-native.sh first" >&2
    exit 1
fi

mkdir -p "$goldens"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for c in "$fixtures"/*.c; do
    name="$(basename "$c" .c)"
    i="$tmp/$name.i"
    s="$goldens/$name.s"
    "$here/scripts/preprocess.sh" "$c" "$i"
    "$rcc" -target=x86/mov "$i" "$s" > /dev/null
    echo "regenerated $name.s ($(wc -l < "$s") lines)"
done
