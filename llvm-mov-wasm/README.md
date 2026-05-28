# llvm-mov-wasm

A WebAssembly port of the sibling [`../llvm-mov`](../llvm-mov) backend.
Runs `llvm-mov-llc` (LLVM IR → mov-target x86-32 assembly) in Node or in
the browser.

Combined with the `as.wasm` / `ld.wasm` from
[`../movfuscator-wasm`](../movfuscator-wasm), the full

```
.ll ── llvm-mov-llc.wasm ──→ .s ── as.wasm ──→ .o ── ld.wasm ──→ ELF32
```

pipeline runs entirely in the browser.

## Quick start

```bash
make setup       # clone LLVM 22.1.x into vendor/
make build       # emcmake LLVM + the Mov backend + the driver
make test        # parity vs native ../llvm-mov/build/bin/llvm-mov-llc
```

## Usage (Node / browser ESM)

```js
import { compile } from './llvm-mov.mjs';

const asm = await compile(`
  target triple = "mov-unknown-linux-gnu"
  define i32 @main() {
    ret i32 42
  }
`);
console.log(asm); // mov-target x86-32 GAS-syntax assembly
```

For the full `.ll → ELF32` pipeline, pair with `../movfuscator-wasm`'s
`assemble` and `link` (they are byte-identical with the host toolchain
on `.s → .o → ELF`).
