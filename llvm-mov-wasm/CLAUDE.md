# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this directory.

A WebAssembly port of the sibling [`../llvm-mov/`](../llvm-mov/) backend:
runs `llvm-mov-llc` (`.ll → mov-target x86-32 asm`) inside Node or a
browser tab. The `.s → .o → ELF` tail of the pipeline is provided by the
already-shipping `as.wasm` / `ld.wasm` from `../movfuscator-wasm/`, so the
end-to-end shape is

```
.ll ─llvm-mov-llc.wasm→ .s ─as.wasm→ .o ─ld.wasm→ ELF32
```

The mov-only backend code itself lives in [`../llvm-mov/`](../llvm-mov/).
This subproject only owns the wasm build scripts, the JS wrapper, and the
parity tests. **Do not fork the backend sources here** — every backend
change should land in `../llvm-mov/` and be picked up automatically by
the wasm build that points cmake at the same source tree.

## Operating model

Three things shape every decision here:

1. **Vendored upstreams, never imported.** `vendor/llvm-project/` is
   gitignored. [`scripts/fetch.sh`](scripts/fetch.sh) clones it at a
   pinned `llvmorg-22.1.x` tag. Editing vendor files in place is
   forbidden; convert the change to a patch file under `patches/` so it
   replays on the next `make distclean && make setup`.

2. **System tools for build helpers.** Like `movfuscator-wasm` does for
   binutils' `chew`, we let LLVM's TableGen invocations use the system
   `llvm-tblgen-22` rather than building one as wasm. The point of the
   wasm build is to ship the *runtime* artifact, not to bootstrap LLVM
   from nothing.

3. **Parity TDD against native `llvm-mov-llc`.** The primary signal is
   "the wasm driver emits the same `.s` text as the native driver from
   `../llvm-mov/build/bin/llvm-mov-llc`". Byte-identical `.s` output is
   the gate; once that holds, downstream `.s → ELF` parity comes for
   free from the already-byte-identical `as.wasm` / `ld.wasm`.

## Pipeline

```
.ll ──llvm-mov-llc.wasm──→ .s ──as.wasm──→ .o ──ld.wasm──→ ELF32
                              │
                              └→ tests/run.sh: diff vs native llvm-mov-llc
```

- **llvm-mov-llc.wasm**: the same driver as `../llvm-mov/tools/llvm-mov-llc/`,
  re-linked through `emcmake`. Built against an Emscripten-compiled
  `libLLVM` and our Emscripten-compiled `LLVMMov*` backend libs.
- **as.wasm / ld.wasm**: reused unchanged from
  [`../movfuscator-wasm/build/`](../movfuscator-wasm/build/). See that
  subproject's `CLAUDE.md` for the binutils flags
  (`-mx86-used-note=no` on `as`, `--hash-style=gnu` on `ld`) that keep
  output byte-aligned with the host toolchain.

## Build graph

LLVM is layered in three emcmake steps so a single source edit on the
backend doesn't re-run the multi-hour LLVM-proper build:

| step | what it builds | rebuild trigger |
|---|---|---|
| `scripts/fetch.sh` | `vendor/llvm-project/` at pinned tag | one-shot |
| `scripts/build-wasm-llvm.sh` | `build/llvm-wasm/` — Emscripten LLVM static libs | LLVM tag bump only |
| `scripts/build-wasm-llvm-mov-llc.sh` | `build/llvm-mov-wasm/bin/llvm-mov-llc.{js,wasm}` (links `../llvm-mov/llvm/` against the wasm LLVM) | every backend source edit |

Each script is independently idempotent. `make build` walks the chain.

## Tests

Two layers, both gated on byte-identical parity with native `llvm-mov-llc`:

- **Node-mode parity** (`make test` → `tests/run.sh`): each
  `tests/fixtures/*.ll` is compiled by both the native driver and our
  wasm wrapper, with the `.s` outputs diffed byte-for-byte. Fast loop
  — runs as part of CI.
- **Browser E2E** (`make test-e2e` → Playwright at `tests/e2e/`):
  drives the demo `index.html` in a headless Chromium, clicks Compile
  on every built-in example, and asserts the rendered `.s` text equals
  what native `llvm-mov-llc` produces from the same IR. The harness
  starts its own static server via `playwright.config.js`'s
  `webServer`. The same wasm artifact (MODULARIZE+EXPORT_ES6+MEMFS)
  serves both Node and the browser, so an E2E pass also confirms the
  Node-mode pass holds in the browser environment.

Fixture set is a curated subset of `../llvm-mov/test/Execution/*.ll` —
pick small fixtures that exercise distinct stages.

## Things future Claude has bumped into and shouldn't relearn

- **TableGen must be the system binary**: pass
  `-DLLVM_TABLEGEN=/usr/lib/llvm-22/bin/llvm-tblgen` *and*
  `-DLLVM_TABLEGEN_EXE=/usr/lib/llvm-22/bin/llvm-tblgen` so both the
  LLVM build and our backend's `tablegen()` invocations resolve to the
  fast native tool. Emcmake-built tablegen-as-wasm is technically
  possible but adds a separate native step for no real benefit.
- **`LLVM_TARGETS_TO_BUILD=""`** is intentional. Mov is the only target
  and it's out-of-tree; baking in X86 / AArch64 etc. would balloon the
  wasm by ~50 MB for nothing.

## Further reading

- [`../llvm-mov/DESIGN.md`](../llvm-mov/DESIGN.md) for the backend
  architecture and staged plan.
- [`../movfuscator-wasm/CLAUDE.md`](../movfuscator-wasm/CLAUDE.md) for
  the binutils-as-wasm patterns we mirror here.
- [`README.md`](README.md) for user-facing usage.
