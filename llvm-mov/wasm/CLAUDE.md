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
.c  ──clang.wasm──→ .ll ──llvm-mov-llc.wasm──→ .s ──as.wasm──→ .o ──ld.wasm──→ ELF32
    │                  │
    └→ cToIR()         └→ compile()

.rs ──rustc.wasm──→ .ll  ─┘   (in progress — see "Rust frontend" below)
    │
    └→ rsToIR()

.rs ──host rustc──→ .ll  ─┘   (Node-only bypass — see "host bypass" below)
    │
    └→ rsHostToIR()
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

## Rust frontend (in progress)

Goal: ship a `rustc.wasm` so the whole `.rs → ELF32` pipeline runs
inside Node / a browser tab, with no host rustc required. Once landed,
`rsToIR()` joins `cToIR()` as a sibling entrypoint feeding the same
`compile()` → `as.wasm` → `ld.wasm` tail.

### Version is a registry, not a build flag

Rust moves fast; pinning a single `rustc.wasm` build into this
subproject would lock us out of every later language version. The
wrapper instead carries a **`RUSTC_VERSIONS` table** in
[`llvm-mov.mjs`](llvm-mov.mjs): one row per shippable rustc.wasm
artefact (URL, sysroot URL, supported targets, supported editions,
matching native `rustup` version for parity tests). `rsToIR(src,
{ rustcVersion: '<key>' })` is the only place a caller chooses.
Adding a new Rust version = appending one row + rebuilding artefacts;
no wrapper or test change needed.

The end consumer for this knob is the [`explorer`](../../explorer/)
SPA, which is intended to expose the Rust-version choice as a UI
dropdown the same way it already exposes the toolchain (movfuscator /
llvm-mov clang) choice.

### Why we start on rubrc v0.2.0 (Rust 1.83.0-dev) anyway

Building our own `rustc.wasm` is days of work
([`bjorn3/rust:compile_rustc_for_wasm20`](https://github.com/bjorn3/rust/tree/compile_rustc_for_wasm20)
+ wasi-sdk-22 + a custom sysroot for i686-unknown-linux-gnu).
[`oligamiq/rubrc`](https://github.com/oligamiq/rubrc) already publishes
a prebuilt artefact at `rust_wasm/v0.2.0/rustc_opt.wasm.br` (reports
`1.83.0-dev` at startup; bjorn3 wasm16/17-era; edition ≤ 2021;
sysroots for `wasm32-wasip1` + `x86_64-unknown-linux-gnu`). That's
enough to prove end-to-end wiring works. The "i686 + edition 2024"
delta moves in as a second registry row driven by a self-hosted
artefact.

### Runtime: wasmtime CLI

`rustc.wasm` imports `wasi:thread-spawn` and uses an imported `env.memory`
(i.e. shared memory + wasi-threads). Neither Node's built-in `node:wasi`
nor `@bjorn3/browser_wasi_shim` (single-threaded) handle that. The
driver runs `rustc.wasm` via the `wasmtime` CLI as a subprocess:

```
wasmtime run \
  -S threads=y -S preview2=n -W threads=y -W shared-memory=y \
  --dir <runDir>::/ --dir dist \
  --env RUST_MIN_STACK=16777216 \
  dist/bin/rustc.wasm \
  --sysroot=dist - --target=<triple> --edition=<ed> \
  --crate-type=lib --emit=llvm-ir --out-dir=/ -C codegen-units=1
```

Install:
```
gh release download --repo bytecodealliance/wasmtime --pattern '*x86_64-linux.tar.xz'
mkdir -p ~/.local/wasmtime
tar -xJf wasmtime-*-x86_64-linux.tar.xz -C ~/.local/wasmtime --strip-components=1
```
The driver probes `$PATH` first, then `~/.local/wasmtime/wasmtime`,
then throws an install-hint error.

### Layered status

| layer | state | next step |
|---|---|---|
| Registry API (`RUSTC_VERSIONS` + `rsToIR` validation) | ✅ landed | — |
| Driver (Node mode, `lib/rustc-driver.mjs` via wasmtime subprocess) | ✅ landed | — |
| Cache layout: `build/rustc-cache/<versionKey>/dist/{bin,lib/rustlib/<target>/lib}` | ✅ landed | — |
| Cold-cache in-process dedup + per-PID staging path | ✅ landed | — |
| Smoke test (`tests/run-rust.sh`) | ✅ green on `ret_42.rs` (rubrc v0.2.0) | extend fixture set |
| `'self-bjorn3-wasm20'` registry row (Rust 1.96 / i686 / edition 2024) | ✅ slot defined; `scripts/build-wasm-rustc.sh` documented | run the script — multi-hour build |
| Browser driver (`@oligami/rustc-browser-wasi_shim` + WASIFarm) | not started | mirror Node driver's shape for the explorer page |
| Host-rustc bypass (`rsHostToIR` + `tests/run-rust-host.sh`) | ✅ landed (Node-only) | wire into explorer through a backend service or as a Node-side build step |
| Explorer UI integration | not started | dropdown + dynamic-import in `explorer/src/lib/wrappers.ts` |

### Self-hosted artefact (`scripts/build-wasm-rustc.sh`)

The 2nd registry row `'self-bjorn3-wasm20'` carries `artefacts.local = true`,
which makes the driver skip its fetch logic and expect the cache tree
at `build/rustc-cache/self-bjorn3-wasm20/dist/…` to already exist.
[`scripts/build-wasm-rustc.sh`](scripts/build-wasm-rustc.sh) is the
only thing allowed to populate it; until the script runs, calling
`rsToIR(src, { rustcVersion: 'self-bjorn3-wasm20' })` throws an
actionable error pointing at the script.

What the script does, in shape:

1. `git clone https://github.com/bjorn3/rust @ compile_rustc_for_wasm20`
   into `vendor/rust/` (pinned at a SHA recorded in the script header).
2. Stage `wasi-sdk-22` into `vendor/wasi-sdk-22.0/`.
3. Apply any local patches under `patches/wasm-rustc/` (none yet).
4. Write a `config.toml` and run `./x.py install` with `WASI_SDK_PATH` /
   `WASI_SYSROOT` / `WASI_CLANG_WRAPPER_LINKER` env set, prefix-installing
   directly into `build/rustc-cache/self-bjorn3-wasm20/dist/`.
5. Drop the per-target `.complete-sysroot-<target>` markers the driver
   keys off, then echo a one-liner that exercises the row.

Resource cost: hours of CPU, ~3 GB vendored source, ~200 MB install
dir, 8 GB+ RAM. Don't run it on a laptop battery.

### Tests

[`tests/run-rust.sh`](tests/run-rust.sh) is a *smoke* gate (not parity)
because the wasm rustc is intentionally older than the host rustc. It
asserts `rsToIR()` returns text containing `define … @rust_main(`.
Strict byte-identical parity comes when both sides are the same Rust
version — at that point the script gets a `RUSTUP_VERSION` env var,
runs `rustup run <ver> rustc …` on the native side, and diffs again.
Fixture set starts at
[`tests/fixtures/ret_42.rs`](tests/fixtures/ret_42.rs) (edition 2021
mirror of `ret_42.c`).

### Caveat: target mismatch with the mov backend

The first-cut artefact only ships sysroots for `wasm32-wasip1` and
`x86_64-unknown-linux-gnu`. Neither matches our backend's
`i686-unknown-linux-gnu` ABI / data layout — so feeding the IR through
`llvm-mov-llc.wasm` will fail until we land a self-hosted artefact
with an `i686` sysroot. The `rsToIR` half is complete; the join with
`compile()` is what's gated on the next artefact.

## Rust frontend (host bypass)

`rsHostToIR(source)` runs the host `rustc` as a subprocess and returns
LLVM IR text. Same I/O shape as `rsToIR()` but no wasm artefact is
needed — works today, on the dev box, for any `--target` that
`rustup target add` has installed.

The point of this path: until the in-wasm rustc story (`rsToIR`
above) ships an i686-aware artefact, `rsHostToIR(..., { target:
'i686-unknown-linux-gnu' })` is the way to get IR that
`compile()` (wasm llvm-mov-llc) actually accepts after the usual
`mtriple: 'mov-unknown-linux-gnu'` override — i.e. the explorer can
expose a working Rust path *now* by sticking host-emitted IR into the
same `.ll → .s → .o → ELF32` wasm tail the C path uses.

Trade-off: Node-only by construction (spawns a subprocess + touches
the filesystem). A browser-side bypass would need a backend service
(e.g. a tiny `compile-server` over WebSocket that returns the IR).

```js
import { rsHostToIR, compile } from './llvm-mov.mjs';

const src = `#![no_std]
    #[panic_handler] fn p(_:&core::panic::PanicInfo)->!{loop{}}
    #[unsafe(no_mangle)] pub extern "C" fn rust_main() -> i32 { 42 }`;

const ir  = await rsHostToIR(src);  // i686-unknown-linux-gnu IR
const asm = await compile(ir, { mtriple: 'mov-unknown-linux-gnu' });
// → mov-target x86-32 GAS asm; ready for as.wasm / ld.wasm.
```

Prereq on the host:
```
rustup target add i686-unknown-linux-gnu
```

Smoke gate: [`tests/run-rust-host.sh`](tests/run-rust-host.sh) (=
`make test-rust-host`). Asserts `rsHostToIR(host_ret_42.rs)` returns
IR containing `define … @rust_main(`. Independent of the wasm rustc
artefact, so doesn't need `wasmtime`.

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
