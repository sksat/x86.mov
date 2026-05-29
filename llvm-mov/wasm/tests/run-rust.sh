#!/usr/bin/env bash
# Rust frontend smoke test.
#
# Pipeline shape (once `rsToIR` is implemented):
#
#   .rs ──rustc.wasm──→ .ll ──llvm-mov-llc.wasm──→ .s ──as.wasm──→ .o ──ld.wasm──→ ELF32
#       │                  │
#       └→ rsToIR()        └→ compile()  (already implemented)
#
# This script is a *smoke* gate, not parity — the rubrc v0.2.0 artefact
# is Rust 1.79 while the host rustc is whatever's on PATH (typically a
# couple of versions newer), so byte-identical IR is not yet realistic.
# Strict parity moves in once we land a matched-version artefact (the
# `nativeRustup` field in RUSTC_VERSIONS is the hint for that —
# `rustup run <ver> rustc …`).
#
# Until rsToIR is wired up the wasm side throws with the next-step
# message defined in lib/rustc-driver.mjs. That's the TDD red.

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

pass=0
fail=0
fail_names=()

run_rs_fixture() {
    local rs="$1" name dir
    name="$(basename "$rs" .rs)"
    dir="$work/$name"
    mkdir -p "$dir"

    # Wasm side: rsToIR() must (a) return a string that (b) looks like
    # LLVM IR for our fixture (`define i32 @rust_main`). No native
    # comparison yet — see header.
    local wasm_ll="$dir/wasm.ll"
    local node_log="$dir/wasm.log"
    if node --input-type=module -e "
        import { readFileSync, writeFileSync } from 'node:fs';
        import { rsToIR } from '$root/llvm-mov.mjs';
        const src = readFileSync('$rs', 'utf8');
        const ir = await rsToIR(src, { name: '$name.rs' });
        writeFileSync('$wasm_ll', ir);
    " 2>"$node_log"; then
        if grep -qE 'define [^ ]+ @rust_main' "$wasm_ll"; then
            pass=$((pass + 1))
            echo "PASS  $name (rs smoke)"
        else
            fail=$((fail + 1))
            fail_names+=("$name(no rust_main in IR)")
            echo "FAIL  $name (rs smoke) — IR missing 'define … @rust_main'"
            head -20 "$wasm_ll" | sed 's/^/    /'
        fi
    else
        fail=$((fail + 1))
        fail_names+=("$name(node threw)")
        echo "FAIL  $name (rs smoke) — node side threw"
        sed 's/^/    /' "$node_log" | head -20
    fi
}

shopt -s nullglob
for rs in "$here"/fixtures/*.rs; do
    run_rs_fixture "$rs"
done
shopt -u nullglob

echo
echo "rust smoke: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
    echo "failing:"
    for n in "${fail_names[@]}"; do echo "  - $n"; done
    exit 1
fi
