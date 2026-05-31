#!/usr/bin/env bash
# Host-rustc bypass smoke test.
#
# Drives the host `rustc` (whatever's on $PATH or $RUSTC) through
# `rsHostToIR()` and asserts the returned LLVM IR contains a
# `define ... @rust_main(` line. This is the "works today" Rust
# frontend — sister to `tests/run-rust.sh` (which exercises the
# wasm-hosted rubrc artefact, currently only emits wasm32 IR).
#
# Prereq: `rustup target add i686-unknown-linux-gnu` on the host.
# Without it rustc dies with "the toolchain doesn't support …".

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"

if ! command -v "${RUSTC:-rustc}" >/dev/null 2>&1; then
    echo "error: ${RUSTC:-rustc} not on PATH — set RUSTC=… to override" >&2
    exit 2
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

pass=0
fail=0
fail_names=()

run_rs_host_fixture() {
    local rs="$1" name dir
    name="$(basename "$rs" .rs)"
    dir="$work/$name"
    mkdir -p "$dir"

    local wasm_ll="$dir/host.ll"
    local node_log="$dir/host.log"
    if node --input-type=module -e "
        import { readFileSync, writeFileSync } from 'node:fs';
        import { rsHostToIR } from '$root/llvm-mov.mjs';
        const src = readFileSync('$rs', 'utf8');
        const ir = await rsHostToIR(src, { name: '$name.rs' });
        writeFileSync('$wasm_ll', ir);
    " 2>"$node_log"; then
        if grep -qE 'define .* @rust_main\(' "$wasm_ll"; then
            pass=$((pass + 1))
            echo "PASS  $name (host-rs smoke)"
        else
            fail=$((fail + 1))
            fail_names+=("$name(no rust_main in IR)")
            echo "FAIL  $name (host-rs smoke) — IR missing 'define … @rust_main('"
            head -20 "$wasm_ll" | sed 's/^/    /'
        fi
    else
        fail=$((fail + 1))
        fail_names+=("$name(node threw)")
        echo "FAIL  $name (host-rs smoke) — node side threw"
        sed 's/^/    /' "$node_log" | head -20
    fi
}

shopt -s nullglob
for rs in "$here"/fixtures/host_*.rs; do
    run_rs_host_fixture "$rs"
done
shopt -u nullglob

echo
echo "host-rust smoke: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
    echo "failing:"
    for n in "${fail_names[@]}"; do echo "  - $n"; done
    exit 1
fi
