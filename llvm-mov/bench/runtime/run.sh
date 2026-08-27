#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

HERE="$(cd "$(dirname "$0")" && pwd)"
LLVM_MOV="$(cd "$HERE/../.." && pwd)"
ROOT="$(cd "$LLVM_MOV/.." && pwd)"
CURRENT_LLC="${CURRENT_LLC:-$LLVM_MOV/build/bin/llvm-mov-llc}"
BASELINE_LLC="${BASELINE_LLC:-}"
MOVIE86="${MOVIE86:-$ROOT/movie86/target/release/movie86}"
MOVCC="${MOVCC:-$ROOT/movfuscator-wasm/vendor/movfuscator/build/movcc}"
CLANG="${CLANG:-clang-22}"
RUNS="${RUNS:-10}"
TURBO_RUNS="${TURBO_RUNS:-25}"

for value in RUNS TURBO_RUNS; do
    if ! [[ "${!value}" =~ ^[1-9][0-9]*$ ]]; then
        echo "error: $value must be a positive integer" >&2
        exit 2
    fi
done

for tool in "$CURRENT_LLC" "$MOVIE86" "$MOVCC" "$CLANG" hyperfine; do
    if ! command -v "$tool" >/dev/null 2>&1 && ! [ -x "$tool" ]; then
        echo "error: required tool not found: $tool" >&2
        exit 2
    fi
done
if [ -n "$BASELINE_LLC" ] && ! [ -x "$BASELINE_LLC" ]; then
    echo "error: BASELINE_LLC is not executable: $BASELINE_LLC" >&2
    exit 2
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/start.s" <<'EOF'
.intel_syntax noprefix
.section .text
.globl _start
_start:
    call main
    mov ebx, eax
    mov eax, 1
    int 0x80
EOF
as --32 "$WORK/start.s" -o "$WORK/start.o"

libm32="$(cc -m32 -print-file-name=libm.so 2>/dev/null || true)"
movcc_libarg=""
if [ -f "$libm32" ]; then
    movcc_libarg="-Wl-L$(cd "$(dirname "$libm32")" && pwd)"
fi

build_llvm_mov() {
    local llc="$1" src="$2" out="$3"
    mkdir -p "$out"
    "$CLANG" -m32 -O0 -emit-llvm -S "$src" -o "$out/input.ll"
    "$llc" -verify-machineinstrs "$out/input.ll" \
        -mtriple=mov-unknown-linux-gnu -o "$out/program.s"
    as --32 "$out/program.s" -o "$out/program.o"
    ld -m elf_i386 -static --gc-sections \
        "$WORK/start.o" "$out/program.o" -o "$out/program.elf"
}

build_movfuscator() {
    local src="$1" out="$2"
    local -a libargs=()
    mkdir -p "$out"
    if [ -n "$movcc_libarg" ]; then
        libargs+=("$movcc_libarg")
    fi
    "$MOVCC" "${libargs[@]}" "$src" \
        -o "$out/program.elf" >"$out/build.log" 2>&1
}

movie_steps() {
    local elf="$1" snap="$2"
    local output status
    set +e
    output="$($MOVIE86 --max-steps 2000000000 \
        --snapshot-on-stop "$snap" "$elf" 2>&1)"
    status=$?
    set -e
    if [ "$status" -eq 124 ]; then
        echo "max-steps"
        return
    fi
    local steps
    steps="$(sed -n 's/.* at step \([0-9][0-9]*\)$/\1/p' <<<"$output")"
    if [ -z "$steps" ]; then
        echo "error" >&2
        return 1
    fi
    echo "$steps"
}

turbo_median() {
    local elf="$1" runs="$2"
    (
        cd "$ROOT/turbo86"
        TURBO86_RUNTIME_BENCH_ELF="$elf" \
        TURBO86_RUNTIME_BENCH_RUNS="$runs" \
            go test ./runner -run TestRuntimeBenchELF -count=1 -v
    ) | sed -n 's/.*median_ns=\([0-9][0-9]*\).*/\1/p'
}

fixtures=(bitops shift multiply empty fib_rec)
for name in "${fixtures[@]}"; do
    if [ "$name" = fib_rec ]; then
        src="$LLVM_MOV/bench/fixtures/fib_rec.c"
        turbo_runs=15
    else
        src="$HERE/fixtures/$name.c"
        turbo_runs="$TURBO_RUNS"
    fi
    if [ "$name" = empty ]; then
        turbo_runs=51
    fi
    echo "== $name =="
    build_llvm_mov "$CURRENT_LLC" "$src" "$WORK/$name/current"
    current_elf="$WORK/$name/current/program.elf"
    echo "movie86 current steps: $(movie_steps "$current_elf" "$WORK/$name/current.snap")"
    echo "turbo86 current median_ns: $(turbo_median "$current_elf" "$turbo_runs")"

    if [ -n "$BASELINE_LLC" ]; then
        build_llvm_mov "$BASELINE_LLC" "$src" "$WORK/$name/baseline"
        baseline_elf="$WORK/$name/baseline/program.elf"
        echo "movie86 baseline steps: $(movie_steps "$baseline_elf" "$WORK/$name/baseline.snap")"
        echo "turbo86 baseline median_ns: $(turbo_median "$baseline_elf" "$turbo_runs")"
    fi

    if [ "$name" != empty ]; then
        build_movfuscator "$src" "$WORK/$name/movfuscator"
        hyperfine --ignore-failure --shell=none --warmup 2 --runs "$RUNS" \
            -n "llvm-mov-$name" "$current_elf" \
            -n "movfuscator-$name" "$WORK/$name/movfuscator/program.elf"
    fi
done
