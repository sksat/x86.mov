#!/usr/bin/env bash
# Benchmark: run the full .c → ELF pipeline through three back-ends and
# write a markdown report to bench/results.md.
#
#   native        host cpp + rcc + as + ld (the reference)
#   wasm-node     build/{cpp,rcc,as,ld}.js under Node + NODERAWFS, one
#                 subprocess per stage (typical CI shape)
#   wasm-browser  movfuscator.mjs (MEMFS, fresh module per call) —
#                 the path users actually hit in the browser, minus the
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
wasm_as_js="$here/build/as.js"
wasm_ld_js="$here/build/ld.js"
browser_wrapper="$here/movfuscator.mjs"
B="$vendor/build"
SF="$vendor/movfuscator/lib"

required=(
    "$native_cpp" "$native_rcc"
    "$wasm_cpp_js" "$wasm_rcc_js" "$wasm_as_js" "$wasm_ld_js"
    "$browser_wrapper"
    "$B/crt0.o" "$B/crtf.o" "$B/crtd.o" "$SF/softfloat32.o"
    "$here/lib"
)
for p in "${required[@]}"; do
    if [ ! -e "$p" ]; then
        echo "missing: $p" >&2
        echo "run: make build-native build-wasm build-wasm-as build-wasm-as-browser build-wasm-ld-browser stage-link-libs" >&2
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

DEFAULT_FIXTURES="return42 hello upstream-prime upstream-hanoi upstream-mandelbrot upstream-mersenne upstream-ray3 upstream-md5"
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

# Link flags (shared by native ld and wasm-node ld).
LINK_FLAGS=(
    -m elf_i386 --hash-style=gnu
    -dynamic-linker /lib/ld-linux.so.2
    -L"$B" -L"$B/gcc/32" -L/usr/lib32 -L/lib32
    -lgcc -lc -lm
)

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

measure_rss_kb() {
    local cmd="$1"
    local tf="$tmp/time.out"
    /usr/bin/time -v -o "$tf" bash -c "$cmd" > /dev/null 2>&1 || true
    awk '/Maximum resident set size/ {print $NF}' "$tf"
}

format_mb() {
    awk -v k="$1" 'BEGIN { if (k+0 == 0) print "n/a"; else printf "%.1f MB\n", k / 1024 }'
}

results="$out/results.md"
{
    echo "# movfuscator-wasm benchmark"
    echo
    echo "_$(date -u +%FT%TZ) · $(uname -srm) · $(node --version) · $(hyperfine --version)_"
    echo
    echo "Three back-ends running the full \`.c → ELF\` pipeline (cpp + rcc + as + ld) are compared per fixture:"
    echo
    echo "- **native**: host \`cpp\`, \`rcc\`, \`/usr/bin/as\`, \`/usr/bin/ld\` (host x86_64)"
    echo "- **wasm-node**: \`build/{cpp,rcc,as,ld}.js\` under Node (NODERAWFS), one subprocess per stage"
    echo "- **wasm-browser**: \`movfuscator.mjs\` under Node ESM (MEMFS — same code as in-browser, minus network fetch)"
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

    # All three back-ends finish at $tmp/<tag>.elf so the link step has the
    # same I/O cost shape on every run.
    cmd_native="$native_cpp ${CPP_FLAGS[*]} $fixtures/$n.c $tmp/n.i \
        && $native_rcc -target=x86/mov $tmp/n.i $tmp/n.s \
        && /usr/bin/as --32 -mx86-used-note=no -o $tmp/n.o $tmp/n.s \
        && /usr/bin/ld ${LINK_FLAGS[*]} $B/crt0.o $tmp/n.o $B/crtf.o $B/crtd.o $SF/softfloat32.o -o $tmp/n.elf"
    cmd_wnode="node $wasm_cpp_js ${CPP_FLAGS[*]} $fixtures/$n.c $tmp/wn.i \
        && node $wasm_rcc_js -target=x86/mov $tmp/wn.i $tmp/wn.s \
        && node $wasm_as_js --32 -mx86-used-note=no -o $tmp/wn.o $tmp/wn.s \
        && node $wasm_ld_js ${LINK_FLAGS[*]} $B/crt0.o $tmp/wn.o $B/crtf.o $B/crtd.o $SF/softfloat32.o -o $tmp/wn.elf"
    cmd_wbrow="node $here/tests/bench-browser.mjs $fixtures/$n.c"

    hyperfine --warmup 1 --runs 5 --shell=bash \
        -n native       "$cmd_native" \
        -n wasm-node    "$cmd_wnode" \
        -n wasm-browser "$cmd_wbrow" \
        --export-markdown "$md"

    echo
    echo "  -- peak RSS (single run via /usr/bin/time -v) --"
    rss_native=$(measure_rss_kb "$cmd_native")
    rss_wnode=$(measure_rss_kb  "$cmd_wnode")
    rss_wbrow=$(measure_rss_kb  "$cmd_wbrow")
    printf "  %-13s %s\n" "native"       "$(format_mb "$rss_native")"
    printf "  %-13s %s\n" "wasm-node"    "$(format_mb "$rss_wnode")"
    printf "  %-13s %s\n" "wasm-browser" "$(format_mb "$rss_wbrow")"

    {
        echo "## $n"
        echo
        cat "$md"
        echo
        echo "| pipeline | peak RSS |"
        echo "|---|---:|"
        echo "| native | $(format_mb "$rss_native") |"
        echo "| wasm-node | $(format_mb "$rss_wnode") |"
        echo "| wasm-browser | $(format_mb "$rss_wbrow") |"
        echo
    } >> "$results"
done

echo
echo "wrote $results"
