#!/usr/bin/env bash
# Build the movie86-wasm crate to wasm32-unknown-unknown and run
# wasm-bindgen on the artifact. Output lands in build/browser/, sibling
# to movie86-wasm/movie86.mjs / index.html — same shape movfuscator-wasm
# uses so `make stage-deploy` and `make serve` have a single layout to
# reason about.

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
out="$here/build/browser"

if ! command -v wasm-bindgen >/dev/null 2>&1; then
    echo "wasm-bindgen CLI not found. install with:" >&2
    echo "    cargo install wasm-bindgen-cli --version 0.2.122 --locked" >&2
    exit 1
fi

mkdir -p "$out"

cd "$here"
cargo build --release --target wasm32-unknown-unknown

wasm-bindgen \
    --target web \
    --out-dir "$out" \
    --no-typescript \
    target/wasm32-unknown-unknown/release/movie86_wasm.wasm

# Emscripten ESM loaders need a `{"type":"module"}` package.json next to
# the .js shims so Node + strict ESM resolvers parse the bg.js as a
# module. wasm-bindgen's --target web output is already an ES module,
# but matching the movfuscator-wasm layout keeps the deploy script
# uniform.
cat > "$out/package.json" <<'EOF'
{ "type": "module" }
EOF

echo "built $(du -sh "$out/movie86_wasm_bg.wasm" | cut -f1) wasm into $out"
