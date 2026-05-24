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

# Multi-arch include subdir — `bits/`, `gnu/`, `sys/` live under it on
# Debian/Ubuntu but the segment name (x86_64-linux-gnu / i386-linux-gnu /
# …) varies. Ask gcc rather than hardcoding a triple.
multiarch="$(gcc -print-multiarch 2>/dev/null || true)"
if [ -z "$multiarch" ] || [ ! -d "/usr/include/$multiarch" ]; then
    # Fallback for distros that don't use the multi-arch layout (Arch,
    # Fedora, …) — bits/gnu/sys are already directly under /usr/include.
    multiarch=""
fi

# Headers GNU cpp pre-includes implicitly (so they don't appear in -H
# output) but LCC cpp requires explicitly via features.h:
#   - stdc-predef.h
#   - gnu/stubs-32.h (selected by stubs.h when __x86_64__ isn't defined —
#     LCC cpp is always in that branch since we target i386)
copy_to /usr/include/stdc-predef.h "$out/usr-include/stdc-predef.h"
if [ -n "$multiarch" ] && [ -f "/usr/include/$multiarch/gnu/stubs-32.h" ]; then
    copy_to "/usr/include/$multiarch/gnu/stubs-32.h" "$out/usr-include/gnu/stubs-32.h"
elif [ -f /usr/include/gnu/stubs-32.h ]; then
    copy_to /usr/include/gnu/stubs-32.h "$out/usr-include/gnu/stubs-32.h"
else
    echo "could not locate gnu/stubs-32.h (multiarch='$multiarch')" >&2
    echo "install libc6-dev-i386 (Debian/Ubuntu) or glibc-devel.i686 (Fedora)" >&2
    exit 1
fi

# Collected from cpp -H. We strip the multi-arch segment because
# /usr/include/{bits,gnu,sys} are symlinks to it on the host — LCC cpp
# doesn't follow that and searches /usr/include/<sub>/... directly.
# Use the gcc-reported $multiarch as the trigger so this isn't tied to
# any specific triple list.
multiarch_prefix=""
[ -n "$multiarch" ] && multiarch_prefix="/usr/include/$multiarch/"
count=2
while read -r path; do
    case "$path" in
        # `$multiarch_prefix` is empty on non-multi-arch distros, so the
        # pattern degenerates to `/*` and never matches /usr/include/...,
        # which is exactly what we want: fall through to the plain branch.
        ${multiarch_prefix:-/__no_match__/}*)
            rel="${path#"$multiarch_prefix"}"
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
