# llvm-mov/wasm

A WebAssembly port of the parent [`../`](../) (`llvm-mov`) backend.
Runs clang + `llvm-mov-llc` (C → LLVM IR → mov-target x86-32 assembly)
in Node or in the browser. Deployed at `/llvm-mov/`.

Combined with the `as.wasm` / `ld.wasm` from
[`../../movfuscator-wasm`](../../movfuscator-wasm), the full

```
.c ── clang.wasm ──→ .ll ── llvm-mov-llc.wasm ──→ .s ── as.wasm ──→ .o ── ld.wasm ──→ ELF32
```

pipeline runs entirely in the browser.

## Quick start

```bash
make setup       # clone LLVM 22.1.x into vendor/
make build       # emcmake LLVM + clang + the Mov backend + the drivers
make test        # parity vs native clang-22 + ../build/bin/llvm-mov-llc
make test-e2e    # Playwright (headless Chromium) parity on the demo page
make stage-deploy  # stage ../../dist/llvm-mov/ for Cloudflare Pages
```

## Usage (Node / browser ESM)

```js
import { compileC, compile } from './llvm-mov.mjs';

// C → mov-target x86-32 assembly
const asm = await compileC('int main(void) { return 42; }', { optLevel: '2' });

// Or feed LLVM IR directly (skips the clang frontend, smaller wasm
// dependency surface):
const asm2 = await compile(`
  target triple = "mov-unknown-linux-gnu"
  define i32 @main() { ret i32 42 }
`);
```

For the full `.ll → ELF32` tail of the pipeline, pair with
`../../movfuscator-wasm`'s `assemble` and `link` (they are
byte-identical with the host toolchain on `.s → .o → ELF`).
