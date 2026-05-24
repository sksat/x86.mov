#!/usr/bin/env bash
# Benchmark: compile each selected fixture three ways via hyperfine and
# write a markdown report to bench/results.md.
#
#   native        host LCC cpp + native rcc (the reference)
#   wasm-node     build/cpp.js + build/rcc.js via Node + NODERAWFS
#   wasm-browser  web/movfuscator.mjs (MEMFS, fresh module per call) — the
#                 path users actually hit in the browser, minus the
#                 over-the-network fetch
#
# Override the fixture set with:  BENCH_FIXTURES="hello upstream-ray3" make bench

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
vendor="$here/vendor/movfuscator"
fixtures="$here/tests/fixtures"
out="$here/bench"
mkdir -p "$out"

native_cpp="$vendor/build/cpp"
native_rcc="$vendor/build/rcc"
wasm_cpp_js="$here/build/cpp.js"
wasm_rcc_js="$here/build/rcc.js"
browser_wrapper="$here/web/movfuscator.mjs"

for p in "$native_cpp" "$native_rcc" "$wasm_cpp_js" "$wasm_rcc_js" "$browser_wrapper"; do
    if [ ! -e "$p" ]; then
        echo "missing: $p" >&2
        echo "run: make build-native build-wasm build-wasm-browser" >&2
        exit 1
    fi
done

if [ -z "${EMSDK:-}" ] && [ -f "$HOME/emsdk/emsdk_env.sh" ]; then
    # shellcheck disable=SC1091
    EMSDK_QUIET=1 source "$HOME/emsdk/emsdk_env.sh" > /dev/null
fi

if ! command -v hyperfine > /dev/null; then
    echo "hyperfine not installed (apt install hyperfine)" >&2
    exit 1
fi

DEFAULT_FIXTURES="return42 hello upstream-prime upstream-hanoi upstream-mandelbrot upstream-mersenne upstream-ray3"
FIXTURES="${BENCH_FIXTURES:-$DEFAULT_FIXTURES}"

CPP_FLAGS=(
    -U__GNUC__ -D_POSIX_SOURCE -D__STRICT_ANSI__
    -Dunix -Di386 -Dlinux
    -D__unix__ -D__i386__ -D__linux__
    -D__signed__=signed -D__LCC__
    -I"$vendor/build/include"
    -I"$vendor/build/gcc/include"
    -I/usr/include
)

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

results="$out/results.md"
{
    echo "# movfuscator-wasm benchmark"
    echo
    echo "_$(date -u +%FT%TZ) · $(uname -srm) · $(node --version) · $(hyperfine --version)_"
    echo
    echo "Three implementations of the .c → mov asm pipeline are compared per fixture:"
    echo
    echo "- **native**: \`$(basename "$native_cpp")\` + \`$(basename "$native_rcc")\` (host x86_64)"
    echo "- **wasm-node**: \`build/{cpp,rcc}.js\` under Node (NODERAWFS)"
    echo "- **wasm-browser**: \`web/movfuscator.mjs\` under Node ESM (MEMFS — same code as in-browser, minus network fetch)"
    echo
    echo "| fixture | asm lines |"
    echo "|---|---:|"
    for n in $FIXTURES; do
        lines="$(wc -l < "$here/tests/goldens/$n.s" 2>/dev/null || echo 0)"
        echo "| \`$n\` | $lines |"
    done
    echo
} > "$results"

for n in $FIXTURES; do
    echo
    echo "==========  $n  =========="
    md="$tmp/$n.md"
    cmd_native="$native_cpp ${CPP_FLAGS[*]} $fixtures/$n.c $tmp/n.i && $native_rcc -target=x86/mov $tmp/n.i $tmp/n.s"
    cmd_wnode="node $wasm_cpp_js ${CPP_FLAGS[*]} $fixtures/$n.c $tmp/wn.i && node $wasm_rcc_js -target=x86/mov $tmp/wn.i $tmp/wn.s"
    cmd_wbrow="node $here/tests/bench-browser.mjs $fixtures/$n.c"

    hyperfine --warmup 1 --runs 5 --shell=bash \
        -n native       "$cmd_native" \
        -n wasm-node    "$cmd_wnode" \
        -n wasm-browser "$cmd_wbrow" \
        --export-markdown "$md"

    {
        echo "## $n"
        echo
        cat "$md"
        echo
    } >> "$results"
done

echo
echo "wrote $results"
