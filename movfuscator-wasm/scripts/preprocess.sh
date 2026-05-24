#!/usr/bin/env bash
# Preprocess a .c file the same way upstream lcc driver does.
# Usage: preprocess.sh INPUT.c OUTPUT.i
#
# Uses the lcc-bundled headers from vendor/movfuscator/build/include so that
# stdio.h etc. come from LCC (C89) rather than the host glibc (which uses
# C99 features that LCC rejects — see upstream issue #51).

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
vendor="$here/vendor/movfuscator"

if [ $# -ne 2 ]; then
    echo "usage: $0 INPUT.c OUTPUT.i" >&2
    exit 2
fi

input="$1"
output="$2"

inc1="$vendor/build/include"
inc2="$vendor/build/gcc/include"

if [ ! -d "$inc1" ] || [ ! -d "$inc2" ]; then
    echo "include dirs missing; run scripts/build-native.sh first" >&2
    exit 1
fi

/usr/bin/cpp \
    -U__GNUC__ -D_POSIX_SOURCE -D__STRICT_ANSI__ \
    -Dunix -Di386 -Dlinux \
    -D__unix__ -D__i386__ -D__linux__ \
    -D__signed__=signed \
    -std=gnu90 -D__LCC__ \
    -I"$inc1" -I"$inc2" -I/usr/include \
    "$input" "$output"
