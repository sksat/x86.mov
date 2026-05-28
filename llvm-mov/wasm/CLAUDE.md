# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this directory.

A WebAssembly port of the parent [`../`](../) (i.e. `llvm-mov`) backend:
runs clang + `llvm-mov-llc` (`.c → .ll → mov-target x86-32 asm`) inside
Node or a browser tab. The `.s → .o → ELF` tail of the pipeline is
provided by the already-shipping `as.wasm` / `ld.wasm` from
`../../movfuscator-wasm/`, so the end-to-end shape is

```
.c ─clang.wasm→ .ll ─llvm-mov-llc.wasm→ .s ─as.wasm→ .o ─ld.wasm→ ELF32
```

This subproject lives at `llvm-mov/wasm/` (nested under the backend
subproject) so a single repository pulls in the LLVM-target backend
sources at `../`. **Do not fork the backend sources here** — every
backend change should land in `../` and be picked up automatically by
the wasm build that points cmake at the same source tree. The deploy
artefact lands at `dist/llvm-mov/` (URL `/llvm-mov/`), preserving the
short URL even though the source moved.

## Operating model

Three things shape every decision here:

1. **Vendored upstreams, never imported.** `vendor/llvm-project/` is
   gitignored. [`scripts/fetch.sh`](scripts/fetch.sh) clones it at a
   pinned `llvmorg-22.1.x` tag. Editing vendor files in place is
   forbidden; convert the change to a patch file under `patches/` so it
   replays on the next `make distclean && make setup`.

2. **System tools for build helpers.** Like `../../movfuscator-wasm`
   does for binutils' `chew`, we let LLVM's TableGen invocations use
   the system `llvm-tblgen-22` rather than building one as wasm. The
   point of the wasm build is to ship the *runtime* artifact, not to
   bootstrap LLVM from nothing.

3. **Parity TDD against native `clang-22` + `llvm-mov-llc`.** The
   primary signal is "the wasm pipeline emits the same `.ll` and `.s`
   text as native `clang-22 → ../build/bin/llvm-mov-llc`".
   Byte-identical text output is the gate at every layer.

## Pipeline

```
.c ──clang.wasm──→ .ll ──llvm-mov-llc.wasm──→ .s ──as.wasm──→ .o ──ld.wasm──→ ELF32
   │                  │
   └→ cToIR()         └→ compile()
```

- **clang.wasm**: a standalone clang driver, statically linked against
  the same `clang*` static libs we build for the backend. Resource-dir
  headers (`stdarg.h` etc.) are baked in via `--embed-file` so no extra
  runtime fetch is needed.
- **llvm-mov-llc.wasm**: the same driver as `../tools/llvm-mov-llc/`,
  re-linked through `emcmake`. Built against an Emscripten-compiled
  `libLLVM` and our Emscripten-compiled `LLVMMov*` backend libs.
- **as.wasm / ld.wasm**: reused unchanged from
  [`../../movfuscator-wasm/build/`](../../movfuscator-wasm/build/).

## Build graph

LLVM is layered so a single source edit on the backend doesn't re-run
the multi-hour LLVM build:

| step | what it builds | rebuild trigger |
|---|---|---|
| `scripts/fetch.sh` | `vendor/llvm-project/` at pinned tag | one-shot |
| `scripts/build-wasm-llvm.sh` | `build/llvm-wasm/` — Emscripten LLVM + clang static libs + resource-dir headers | LLVM tag bump only |
| `scripts/build-wasm-clang.sh` | `build/clang.{js,wasm}` — standalone clang driver (~80 MB wasm) | clang sources or driver flags |
| `scripts/build-wasm-llvm-mov-llc.sh` | `build/llvm-mov-llc.{js,wasm}` — links `../llvm/` against the wasm LLVM | every backend source edit |

Each script is independently idempotent. `make build` walks the chain.

## Tests

Two layers, both gated on byte-identical parity with the native
`clang-22 → ../build/bin/llvm-mov-llc` pipeline:

- **Node-mode parity** (`make test` → `tests/run.sh`): each
  `tests/fixtures/*.ll` and `tests/fixtures/*.c` is compiled through
  both the native pipeline and our wasm wrappers, with both the
  intermediate `.ll` and the final `.s` diffed byte-for-byte. The C
  fixtures run at multiple opt levels (`OPT_LEVELS=("0" "2")`).
- **Browser E2E** (`make test-e2e` → Playwright at `tests/e2e/`):
  drives the demo `index.html` in a headless Chromium, clicks Compile
  on every (example × opt level) pair, and asserts both the rendered
  IR (`#ll`) and asm (`#out`) equal the native reference. The same
  wasm artefacts (MODULARIZE + EXPORT_ES6 + MEMFS) serve both Node and
  the browser, so an E2E pass also confirms the Node-mode pass holds
  in the browser environment.

Fixture set is a curated subset of `../test/Execution/*.ll` (plus
hand-written `.c` counterparts for the C-frontend path).

## Things future Claude has bumped into and shouldn't relearn

- **`-fno-ident` is mandatory** in the clang flag set. Without it, the
  IR's `!llvm.ident` carries the distribution string (e.g. "Debian
  clang 22.1.6 (...)") which then propagates into the asm's `.ident`
  directive. The system clang and the vendored upstream clang stamp
  different strings, and byte parity breaks. Same reason `-march=i386`
  is pinned: the two builds default to different `-mcpu` values
  (i686 vs pentium4).
- **clang IR carries an `i386-unknown-linux-gnu` triple**; llvm-mov-llc
  refuses anything that isn't `mov-...` unless `-mtriple` overrides
  it. The wrapper's `compile()` exposes an `mtriple` opt for this; the
  test runner and the demo both pass `mov-unknown-linux-gnu`.
- **TableGen must be the system binary**: pass
  `-DLLVM_TABLEGEN=/usr/lib/llvm-22/bin/llvm-tblgen` *and*
  `-DLLVM_TABLEGEN_EXE=/usr/lib/llvm-22/bin/llvm-tblgen` so both the
  LLVM build and our backend's `tablegen()` invocations resolve to the
  fast native tool. Emcmake-built tablegen-as-wasm is technically
  possible but adds a separate native step for no real benefit.
- **`LLVM_TARGETS_TO_BUILD=""`** is intentional. Mov is the only target
  and it's out-of-tree; baking in X86 / AArch64 etc. would balloon the
  wasm by ~50 MB for nothing. Clang's frontend doesn't need a backend
  either — it emits LLVM IR via `-emit-llvm`, with target info coming
  from clang's own driver tables.
- **`build-wasm-clang.sh` skips `ninja clang`** in favour of building
  just the driver `.o` files. The cmake-driven `clang` target re-runs
  `wasm-opt` on a 70 MB wasm (~10 min) and produces a non-MODULARIZE
  artefact we'd throw away anyway. Going straight to our own em++ link
  with MODULARIZE flags saves the duplicate work.

## Further reading

- [`../DESIGN.md`](../DESIGN.md) for the backend architecture and
  staged plan.
- [`../../movfuscator-wasm/CLAUDE.md`](../../movfuscator-wasm/CLAUDE.md)
  for the binutils-as-wasm patterns we mirror here.
- [`README.md`](README.md) for user-facing usage.
