#!/usr/bin/env bash
# Regenerate tests/goldens-o/*.o using the host /usr/bin/as.
# Run after a new fixture is added, an upstream pin changes, or the
# assembler flag set changes — analogous to scripts/regen-goldens.sh
# for the .s pipeline.

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
goldens_s="$here/tests/goldens"
goldens_o="$here/tests/goldens-o"

if ! command -v as > /dev/null; then
    echo "host 'as' missing — apt install binutils" >&2
    exit 1
fi

mkdir -p "$goldens_o"

for s in "$goldens_s"/*.s; do
    name="$(basename "$s" .s)"
    o="$goldens_o/$name.o"
    # -mx86-used-note=no keeps the wasm-as and host-as outputs byte-aligned
    # (modern binutils default-enables a .note.gnu.property section).
    as --32 -mx86-used-note=no -o "$o" "$s"
    echo "regenerated $name.o ($(stat -c %s "$o") bytes)"
done
