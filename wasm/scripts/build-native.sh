#!/usr/bin/env bash
# Build native (host) rcc + cpp via upstream build.sh.
# Used to (a) produce lburg-generated .c files needed by build-wasm.sh,
# and (b) regenerate test golden outputs.

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
vendor="$here/vendor/movfuscator"

if [ ! -d "$vendor" ]; then
    echo "vendor missing; run scripts/fetch.sh first" >&2
    exit 1
fi

cd "$vendor"
./build.sh

echo "native build complete: $vendor/build/rcc"
