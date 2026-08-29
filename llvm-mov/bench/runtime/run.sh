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
CC="${CC:-cc}"
RUNS="${RUNS:-10}"
TURBO_RUNS="${TURBO_RUNS:-25}"

for value in RUNS TURBO_RUNS; do
    if ! [[ "${!value}" =~ ^[1-9][0-9]*$ ]]; then
        echo "error: $value must be a positive integer" >&2
        exit 2
    fi
done

for tool in "$CURRENT_LLC" "$MOVIE86" "$MOVCC" "$CLANG" "$CC" hyperfine; do
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

libm32="$("$CC" -m32 -print-file-name=libm.so 2>/dev/null || true)"
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
    if ! "$MOVCC" "${libargs[@]}" "$src" \
            -o "$out/program.elf" >"$out/build.log" 2>&1; then
        echo "error: movcc failed while building $src" >&2
        cat "$out/build.log" >&2
        return 1
    fi
}

movie_steps() {
    local elf="$1" snap="$2" expected="$3"
    local output status
    set +e
    output="$($MOVIE86 --max-steps 2000000000 \
        --snapshot-on-stop "$snap" "$elf" 2>&1)"
    status=$?
    set -e
    local steps
    steps="$(sed -n 's/.*snapshot (exit) written to .* at step \([0-9][0-9]*\)$/\1/p' <<<"$output")"
    if [ -z "$steps" ] || [ "$status" -ne "$expected" ]; then
        echo "error: movie86 did not run $elf to guest exit (status $status)" >&2
        printf '%s\n' "$output" >&2
        return 1
    fi
    echo "$steps"
}

turbo_median() {
    local elf="$1" runs="$2" expected="$3"
    local output status median
    set +e
    output="$(
        cd "$ROOT/turbo86"
        TURBO86_RUNTIME_BENCH_ELF="$elf" \
        TURBO86_RUNTIME_BENCH_RUNS="$runs" \
        TURBO86_RUNTIME_BENCH_EXPECTED_STATUS="$expected" \
            go test ./runner -run '^TestRuntimeBenchELF$' -count=1 -v 2>&1
    )"
    status=$?
    set -e
    median="$(sed -n 's/.*median_ns=\([0-9][0-9]*\).*/\1/p' <<<"$output")"
    if [ "$status" -ne 0 ] || [ -z "$median" ]; then
        printf '%s\n' "$output" >&2
        return 1
    fi
    echo "$median"
}

read -r -a fixtures <<<"${WORKLOADS:-bitops shift multiply bitscan empty fib_rec}"
for name in "${fixtures[@]}"; do
    case "$name" in
        bitops) expected_status=120 ;;
        shift) expected_status=0 ;;
        multiply) expected_status=163 ;;
        bitscan) expected_status=77 ;;
        empty) expected_status=160 ;;
        fib_rec) expected_status=32 ;;
        *)
            echo "unknown runtime benchmark workload: $name" >&2
            exit 2
            ;;
    esac
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
    current_steps="$(movie_steps "$current_elf" "$WORK/$name/current.snap" "$expected_status")"
    current_turbo_ns="$(turbo_median "$current_elf" "$turbo_runs" "$expected_status")"
    [ -n "$current_turbo_ns" ] || { echo "error: turbo86 produced no timing for $current_elf" >&2; exit 1; }
    echo "movie86 current steps: $current_steps"
    echo "turbo86 current median_ns: $current_turbo_ns"

    if [ -n "$BASELINE_LLC" ]; then
        build_llvm_mov "$BASELINE_LLC" "$src" "$WORK/$name/baseline"
        baseline_elf="$WORK/$name/baseline/program.elf"
        baseline_steps="$(movie_steps "$baseline_elf" "$WORK/$name/baseline.snap" "$expected_status")"
        baseline_turbo_ns="$(turbo_median "$baseline_elf" "$turbo_runs" "$expected_status")"
        [ -n "$baseline_turbo_ns" ] || { echo "error: turbo86 produced no timing for $baseline_elf" >&2; exit 1; }
        echo "movie86 baseline steps: $baseline_steps"
        echo "turbo86 baseline median_ns: $baseline_turbo_ns"
    fi

    if [ "$name" = bitscan ]; then
        echo "movfuscator native: skipped (__builtin_clz/ctz unsupported)"
    elif [ "$name" != empty ]; then
        build_movfuscator "$src" "$WORK/$name/movfuscator"
        movfuscator_elf="$WORK/$name/movfuscator/program.elf"
        movfuscator_expected_status=1
        set +e
        "$current_elf"
        current_status=$?
        "$movfuscator_elf"
        movfuscator_status=$?
        set -e
        if [ "$current_status" -ne "$expected_status" ] || \
                [ "$movfuscator_status" -ne "$movfuscator_expected_status" ]; then
            echo "error: native preflight failed for $name (llvm-mov=$current_status want $expected_status, movfuscator=$movfuscator_status want $movfuscator_expected_status)" >&2
            exit 1
        fi
        hyperfine --shell=none --warmup 2 --runs "$RUNS" \
            -n "llvm-mov-$name" "$HERE/run-expected.sh $expected_status $current_elf" \
            -n "movfuscator-$name" "$HERE/run-expected.sh $movfuscator_expected_status $movfuscator_elf"
    fi
done
