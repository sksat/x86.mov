#!/usr/bin/env bash
# Parity test: every tests/fixtures/*.{ll,c} produces the same .s text
# through our wasm wrappers as through the native
# `../build/bin/llvm-mov-llc` (the parent llvm-mov subproject) + system
# `clang-22` for the C-frontend leg.
#
# That's the primary TDD gate. Byte-identical assembly text is enough —
# any divergence in codegen would show up in our shared `.s` output
# before it shows up downstream in `.o` or ELF.

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
# Two levels up from tests/ → llvm-mov/wasm/ → llvm-mov/.
native_llc="$root/../build/bin/llvm-mov-llc"
native_clang="${CLANG:-clang-22}"
wasm_llc_js="$root/build/llvm-mov-llc.js"
wasm_clang_js="$root/build/clang.js"

if [ ! -x "$native_llc" ]; then
    echo "error: native llvm-mov-llc not built at $native_llc" >&2
    echo "  run: make -C .. build" >&2
    exit 2
fi
if [ ! -f "$wasm_llc_js" ]; then
    echo "error: wasm llvm-mov-llc not built at $wasm_llc_js" >&2
    echo "  run: make build" >&2
    exit 2
fi
if [ ! -f "$wasm_clang_js" ]; then
    echo "error: wasm clang not built at $wasm_clang_js" >&2
    echo "  run: make build-wasm-clang" >&2
    exit 2
fi
if ! command -v "$native_clang" >/dev/null 2>&1; then
    echo "error: native clang ($native_clang) not on PATH — set CLANG=… to override" >&2
    exit 2
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Same base clang flags the wasm wrapper passes (everything except the
# opt level — that's appended per run_c_fixture invocation). Duplicating
# here is intentional: drift between the wrapper and the test is the
# parity test's whole reason for existing.
#
# `-fno-ident` matters even though we test against the same clang
# version on both sides: the system clang and the vendored upstream
# clang stamp different distribution strings into `!llvm.ident`,
# which then propagates into the asm's `.ident` directive and breaks
# byte-identical parity. Suppressing it on both sides keeps the
# comparison meaningful.
CLANG_BASE_FLAGS=(
    -S -emit-llvm
    -target i386-unknown-linux-gnu
    -march=i386
    -fno-stack-protector -fno-builtin -fno-pic
    -fno-ident
    -nostdinc -nostdlibinc
)

# Opt levels exercised by the C parity test. -O0 needs the
# `-disable-O0-optnone` companion (clang otherwise tags every function
# with `optnone`, which our IR passes can't handle); -O1+ doesn't.
OPT_LEVELS=("0" "2")

pass=0
fail=0
fail_names=()

run_ll_fixture() {
    local ll="$1" name native_s wasm_s
    name="$(basename "$ll" .ll)"
    native_s="$work/$name.native.s"
    wasm_s="$work/$name.wasm.s"

    "$native_llc" "$ll" -o "$native_s" 2>"$work/$name.native.log"

    node --input-type=module -e "
        import { readFileSync, writeFileSync } from 'node:fs';
        import { compile } from '$root/llvm-mov.mjs';
        const ir = readFileSync('$ll', 'utf8');
        const asm = await compile(ir, { name: '$name.ll' });
        writeFileSync('$wasm_s', asm);
    " 2>"$work/$name.wasm.log"

    if diff -u "$native_s" "$wasm_s" >"$work/$name.diff" 2>&1; then
        pass=$((pass + 1))
        echo "PASS  $name (.ll)"
    else
        fail=$((fail + 1))
        fail_names+=("$name(.ll)")
        echo "FAIL  $name (.ll)"
        echo "  native vs wasm .s diff:"
        sed 's/^/    /' "$work/$name.diff"
    fi
}

run_c_fixture_at_opt() {
    local c="$1" opt="$2" name dir tag
    name="$(basename "$c" .c)"
    tag="$name.O$opt"
    dir="$work/$tag"
    mkdir -p "$dir"

    # Per-opt-level subdir so native and wasm intermediates / outputs
    # don't collide between runs of the same fixture.
    cp "$c" "$dir/$name.c"

    local clang_flags=("${CLANG_BASE_FLAGS[@]}" -O"$opt")
    if [ "$opt" = "0" ]; then
        clang_flags+=(-Xclang -disable-O0-optnone)
    fi

    # Native side: cd into $dir before running clang so the IR's
    # `source_filename` is the bare basename `$name.c` (same as what
    # MEMFS cwd=/ produces for the wasm side). Without the cd the
    # native IR would have a full `/tmp/...` path baked in and IR
    # parity would fail trivially.
    local native_ll="$dir/native.ll"
    local native_s="$dir/native.s"
    ( cd "$dir" && "$native_clang" "${clang_flags[@]}" "$name.c" -o "native.ll" ) 2>"$dir/clang.log"
    # llvm-mov-llc bakes the input basename into `.file "<x>"`. Use a
    # stable basename `in.ll` for both sides — the wasm wrapper does
    # the same internally via `compile(ir, { name: 'in.ll' })`.
    cp "$native_ll" "$dir/in.ll"
    # clang's IR carries an `i386-unknown-linux-gnu` triple; llvm-mov-llc
    # only accepts a `mov-...` triple unless one is force-overridden.
    # This mirrors what compileC() does in the wasm wrapper.
    "$native_llc" -mtriple=mov-unknown-linux-gnu "$dir/in.ll" -o "$native_s" 2>"$dir/llc.log"

    local wasm_ll="$dir/wasm.ll"
    local wasm_s="$dir/wasm.s"
    node --input-type=module -e "
        import { readFileSync, writeFileSync } from 'node:fs';
        import { cToIR, compile } from '$root/llvm-mov.mjs';
        const src = readFileSync('$c', 'utf8');
        const ir = await cToIR(src, { name: '$name.c', optLevel: '$opt' });
        writeFileSync('$wasm_ll', ir);
        const asm = await compile(ir, { name: 'in.ll', mtriple: 'mov-unknown-linux-gnu' });
        writeFileSync('$wasm_s', asm);
    " 2>"$dir/wasm.log"

    # Two diffs: IR (clang → .ll) and asm (.ll → llvm-mov-llc → .s).
    # We report them as one fixture result so the test output stays
    # readable; the first failing diff is what gets surfaced.
    if ! diff -u "$native_ll" "$wasm_ll" >"$dir/ll.diff" 2>&1; then
        fail=$((fail + 1))
        fail_names+=("$tag(.ll)")
        echo "FAIL  $tag IR parity"
        echo "  native vs wasm .ll diff:"
        sed 's/^/    /' "$dir/ll.diff"
        return
    fi
    if ! diff -u "$native_s" "$wasm_s" >"$dir/s.diff" 2>&1; then
        fail=$((fail + 1))
        fail_names+=("$tag(.s)")
        echo "FAIL  $tag asm parity"
        echo "  native vs wasm .s diff:"
        sed 's/^/    /' "$dir/s.diff"
        return
    fi
    pass=$((pass + 1))
    echo "PASS  $tag (.ll + .s)"
}

shopt -s nullglob
for ll in "$here"/fixtures/*.ll; do run_ll_fixture "$ll"; done
for c in "$here"/fixtures/*.c; do
    for opt in "${OPT_LEVELS[@]}"; do
        run_c_fixture_at_opt "$c" "$opt"
    done
done

echo
echo "Results: $pass pass, $fail fail"
if [ "$fail" -gt 0 ]; then
    echo "Failed fixtures: ${fail_names[*]}"
    exit 1
fi
