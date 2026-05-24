#!/usr/bin/env bash
# Stage the host files wasm-ld needs into web/lib/ so the in-browser
# demo (Phase E-2) can fetch them lazily. Gitignored — re-run after a
# host libc upgrade or after switching machines.

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
B="$here/vendor/movfuscator/build"
SF="$here/vendor/movfuscator/movfuscator/lib"
out="$here/web/lib"

if [ ! -f "$B/crt0.o" ]; then
    echo "$B/crt0.o missing — run scripts/build-native.sh first" >&2
    exit 1
fi

rm -rf "$out"
mkdir -p "$out"

# Mirror host paths so the demo can write each one back to MEMFS at the
# matching location and the existing link command line just works.
## libgcc.a lives under a gcc-version-specific path
## (/usr/lib/gcc/x86_64-linux-gnu/<ver>/32/libgcc.a) which differs across
## Debian / Ubuntu releases. The MEMFS path baked into the wrapper and the
## tests is /usr/lib/gcc/x86_64-linux-gnu/14/32/libgcc.a regardless of the
## host's gcc version, so we just resolve the host file dynamically and
## stage it at the canonical MEMFS location.
host_libgcc_a=$(cc -m32 -print-libgcc-file-name 2>/dev/null || true)
if [ -z "$host_libgcc_a" ] || [ ! -f "$host_libgcc_a" ]; then
    echo "host libgcc.a not found via 'cc -m32 -print-libgcc-file-name' — apt install gcc-multilib libc6-dev-i386" >&2
    exit 1
fi

declare -A LIBS=(
    ["lib32/libc.so.6"]="/lib32/libc.so.6"
    ["lib32/libm.so.6"]="/lib32/libm.so.6"
    ["usr/lib32/libc.so"]="/usr/lib32/libc.so"
    ["usr/lib32/libc_nonshared.a"]="/usr/lib32/libc_nonshared.a"
    ["usr/lib/gcc/x86_64-linux-gnu/14/32/libgcc.a"]="$host_libgcc_a"
    ["lib32/ld-linux.so.2"]="/lib32/ld-linux.so.2"
    # libc.so's linker script has AS_NEEDED ( /lib/ld-linux.so.2 ) so we
    # also need the loader visible at the un-multi-arch /lib/ path.
    ["lib/ld-linux.so.2"]="/lib32/ld-linux.so.2"
    ["movfuscator/crt0.o"]="$B/crt0.o"
    ["movfuscator/crtf.o"]="$B/crtf.o"
    ["movfuscator/crtd.o"]="$B/crtd.o"
    ["movfuscator/softfloat32.o"]="$SF/softfloat32.o"
)

# libm.so is a symlink to libm.so.6 — emit a tiny linker script that GROUPs
# libm.so.6 instead so the demo doesn't have to handle FS symlinks.
mkdir -p "$out/usr/lib32"
cat > "$out/usr/lib32/libm.so" <<'EOF'
GROUP ( /lib32/libm.so.6 )
EOF

for rel in "${!LIBS[@]}"; do
    src="${LIBS[$rel]}"
    dest="$out/$rel"
    mkdir -p "$(dirname "$dest")"
    cp -L "$src" "$dest"
done

total_bytes=$(du -sb "$out" | cut -f1)
echo "staged $(find "$out" -type f | wc -l) files into $out ($(du -sh "$out" | cut -f1))"
