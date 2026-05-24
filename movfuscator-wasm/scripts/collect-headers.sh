#!/usr/bin/env bash
# Collect every host system header that the fixtures transitively #include,
# preserving directory structure under build/embed-headers/usr-include.
# Used by build-wasm-browser.sh as the source for --embed-file.
#
# Discovery is driven by `cpp -H` on each fixture — only files actually
# reached by the existing test corpus are bundled, keeping the wasm small.

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
out="$here/build/embed-headers"

rm -rf "$out"
mkdir -p "$out/usr-include"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for c in "$here"/tests/fixtures/*.c; do
    /usr/bin/cpp -H \
        -U__GNUC__ -D_POSIX_SOURCE -D__STRICT_ANSI__ \
        -Dunix -Di386 -Dlinux \
        -D__unix__ -D__i386__ -D__linux__ \
        -D__signed__=signed -D__LCC__ \
        -I"$here/vendor/movfuscator/build/include" \
        -I"$here/vendor/movfuscator/build/gcc/include" \
        -I/usr/include \
        "$c" /dev/null 2>> "$tmp/all.h.list" || true
done

# cpp -H emits lines like ". /usr/include/stdio.h" — extract unique header paths
grep -oE "/[^ ]+\.h" "$tmp/all.h.list" | sort -u > "$tmp/headers.list"

copy_to() {
    local src="$1" dest="$2"
    mkdir -p "$(dirname "$dest")"
    cp -L "$src" "$dest"
}

# Headers GNU cpp pre-includes implicitly (so they don't appear in -H
# output) but LCC cpp requires explicitly via features.h:
#   - stdc-predef.h
#   - gnu/stubs-32.h (selected by stubs.h when __x86_64__ isn't defined —
#     LCC cpp is always in that branch since we target i386)
copy_to /usr/include/stdc-predef.h "$out/usr-include/stdc-predef.h"
copy_to /usr/include/x86_64-linux-gnu/gnu/stubs-32.h "$out/usr-include/gnu/stubs-32.h"

# Collected from cpp -H. We strip the x86_64-linux-gnu/ multi-arch segment
# because /usr/include/{bits,gnu,sys} are symlinks to it on the host —
# LCC cpp doesn't follow that and searches /usr/include/<sub>/... directly.
count=2
while read -r path; do
    case "$path" in
        /usr/include/x86_64-linux-gnu/*)
            rel="${path#/usr/include/x86_64-linux-gnu/}"
            copy_to "$path" "$out/usr-include/$rel"
            count=$((count+1))
            ;;
        /usr/include/*)
            rel="${path#/usr/include/}"
            copy_to "$path" "$out/usr-include/$rel"
            count=$((count+1))
            ;;
        # LCC bundled and gcc-internal headers are embedded directly from
        # vendor/movfuscator/build/{include,gcc/include} in build-wasm-browser.sh
    esac
done < "$tmp/headers.list"

bytes=$(du -sb "$out/usr-include" | cut -f1)
echo "collected $count /usr/include headers into $out/usr-include (${bytes} bytes)"
