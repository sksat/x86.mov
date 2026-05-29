#!/usr/bin/env bash
# Build the rust-mov-png-decode and rust-mov-bmp-decode-fb example
# crates from llvm-mov/examples/rust/{png_decode,bmp_decode_fb} and
# install the resulting ELFs as movie86/wasm/examples/*.elf so the
# wasm demo's preset dropdown can serve them.
#
# Run after editing either crate's source. The committed .elf in this
# directory is what the deployed page loads; this script just
# regenerates it.
#
# Prereqs:
#   - `cargo` + `rustup target add i686-unknown-linux-gnu`
#   - `llvm-mov/build/bin/llvm-mov-llc` (built via `make -C llvm-mov build`)

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WASM_EX="$(cd "$HERE/.." && pwd)"
ROOT="$(cd "$WASM_EX/../../.." && pwd)"

PNG_CRATE="$ROOT/llvm-mov/examples/rust/png_decode"
BMP_CRATE="$ROOT/llvm-mov/examples/rust/bmp_decode_fb"

if ! [ -x "$ROOT/llvm-mov/build/bin/llvm-mov-llc" ]; then
    echo "install-rust-decoders.sh: llvm-mov-llc missing — run 'make -C llvm-mov build' first" 1>&2
    exit 2
fi

echo "[png_decode] cargo build --release"
( cd "$PNG_CRATE" && cargo build --release --quiet )
cp "$PNG_CRATE/target/i686-unknown-linux-gnu/release/rust-mov-png-decode" \
   "$WASM_EX/png_decode_64x64.elf"
echo "  → $(stat -c %s "$WASM_EX/png_decode_64x64.elf") B"

echo "[bmp_decode_fb] cargo build --release (320×180)"
# Patch the crate's W/H + fixture path so the committed fixture isn't
# accidentally rewritten by the bench's resize loop.
( cd "$BMP_CRATE"
  sed -i 's/const W: usize = [0-9]*;/const W: usize = 320;/' src/main.rs
  sed -i 's/const H: usize = [0-9]*;/const H: usize = 180;/' src/main.rs
  sed -i 's/test_[0-9]*x[0-9]*\.bmp/test_320x180.bmp/' src/main.rs
  # Regenerate the 320×180 BMP fixture (gradient).
  python3 - <<'PY'
import struct, os
W, H = 320, 180
pixel_off = 54
pxSize = W * H * 4
hdr_file = struct.pack('<2sIHHI', b'BM', pixel_off + pxSize, 0, 0, pixel_off)
hdr_dib  = struct.pack('<IiiHHIIiiII', 40, W, H, 1, 32, 0, pxSize, 2835, 2835, 0, 0)
px = bytearray()
for y in range(H - 1, -1, -1):
    for x in range(W):
        px.extend([((x + y) * 2) & 0xff, (y * 4) & 0xff, (x * 4) & 0xff, 0xff])
os.makedirs("fixtures", exist_ok=True)
with open("fixtures/test_320x180.bmp", "wb") as f:
    f.write(hdr_file + hdr_dib + bytes(px))
PY
  cargo build --release --quiet )
cp "$BMP_CRATE/target/i686-unknown-linux-gnu/release/rust-mov-bmp-decode-fb" \
   "$WASM_EX/bmp_decode_320x180.elf"
echo "  → $(stat -c %s "$WASM_EX/bmp_decode_320x180.elf") B"

echo "done. preset dropdown in movie86/wasm/index.html serves these as 'png_decode' / 'bmp_decode'."
