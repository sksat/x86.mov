#!/usr/bin/env bash
# Parity test: every tests/fixtures/*.ll produces the same .s text through
# our wasm wrapper as through the native ../llvm-mov/build/bin/llvm-mov-llc.
#
# That's the primary TDD gate. Byte-identical assembly text is enough —
# any divergence in codegen would show up in our shared `.s` output before
# it shows up downstream in `.o` or ELF.

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
native="$root/../llvm-mov/build/bin/llvm-mov-llc"
wasm_js="$root/build/llvm-mov-llc.js"

if [ ! -x "$native" ]; then
    echo "error: native llvm-mov-llc not built at $native" >&2
    echo "  run: make -C ../llvm-mov build" >&2
    exit 2
fi
if [ ! -f "$wasm_js" ]; then
    echo "error: wasm llvm-mov-llc not built at $wasm_js" >&2
    echo "  run: make build" >&2
    exit 2
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

pass=0
fail=0
fail_names=()

shopt -s nullglob
for ll in "$here"/fixtures/*.ll; do
    name="$(basename "$ll" .ll)"
    native_s="$work/$name.native.s"
    wasm_s="$work/$name.wasm.s"

    # Native reference.
    "$native" "$ll" -o "$native_s" 2>"$work/$name.native.log"

    # Wasm — driven through the node ESM wrapper so the test exercises
    # the same entry point users see. `node --input-type=module -e ...`
    # keeps the inline script self-contained instead of carrying a
    # separate harness file per fixture.
    #
    # The MEMFS basename must match the host file's basename — the native
    # driver bakes it into a `.file "<name>"` directive in the emitted
    # asm. Passing `name: '$name.ll'` makes the wasm `.s` byte-identical
    # to native's.
    node --input-type=module -e "
        import { readFileSync, writeFileSync } from 'node:fs';
        import { compile } from '$root/llvm-mov.mjs';
        const ir = readFileSync('$ll', 'utf8');
        const asm = await compile(ir, { name: '$name.ll' });
        writeFileSync('$wasm_s', asm);
    " 2>"$work/$name.wasm.log"

    if diff -u "$native_s" "$wasm_s" >"$work/$name.diff" 2>&1; then
        pass=$((pass + 1))
        echo "PASS  $name"
    else
        fail=$((fail + 1))
        fail_names+=("$name")
        echo "FAIL  $name"
        echo "  native vs wasm .s diff:"
        sed 's/^/    /' "$work/$name.diff"
    fi
done

echo
echo "Results: $pass pass, $fail fail"
if [ "$fail" -gt 0 ]; then
    echo "Failed fixtures: ${fail_names[*]}"
    exit 1
fi
