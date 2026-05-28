#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ELF="${1:-/tmp/movie86-link/return42.elf}"

cd "$ROOT"
exec cargo run -q -p movie86-cli -- \
  --break-at 0x8049ca9 \
  --watch 0x08486118 \
  --watch 0x08486128 \
  --dump-u32 0x08486118 \
  --dump-u32 0x08486120 \
  --dump-u32 0x08486124 \
  --dump-u32 0x08486128 \
  --dump-u32 0x082860c0 \
  "$ELF"
