#!/usr/bin/env bash
# Preprocess a .c file using LCC's bundled cpp (host build).
# Usage: preprocess.sh INPUT.c OUTPUT.i
#
# Using LCC's own cpp instead of /usr/bin/cpp keeps the native pipeline
# bit-aligned with the wasm pipeline (which uses the same cpp source
# compiled by emcc). Both stay independent of the host glibc's stdio.h
# (which sprinkles C99 __restrict — see upstream issue #51).

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
vendor="$here/vendor/movfuscator"

if [ $# -ne 2 ]; then
    echo "usage: $0 INPUT.c OUTPUT.i" >&2
    exit 2
fi

input="$1"
output="$2"

cpp="$vendor/build/cpp"
inc1="$vendor/build/include"
inc2="$vendor/build/gcc/include"

if [ ! -x "$cpp" ] || [ ! -d "$inc1" ] || [ ! -d "$inc2" ]; then
    echo "lcc cpp/include dirs missing; run scripts/build-native.sh first" >&2
    exit 1
fi

"$cpp" \
    -U__GNUC__ -D_POSIX_SOURCE -D__STRICT_ANSI__ \
    -Dunix -Di386 -Dlinux \
    -D__unix__ -D__i386__ -D__linux__ \
    -D__signed__=signed \
    -D__LCC__ \
    -I"$inc1" -I"$inc2" -I/usr/include \
    "$input" "$output"
