# movfuscator → WebAssembly

WebAssembly port of [movfuscator](https://github.com/xoreaxeaxeax/movfuscator)'s
code generator and preprocessor, so that compiling C to mov-only x86 assembly
can run in any wasm runtime — including a browser tab on [x86.mov](../index.html).

**Scope**:
- Phase A: `rcc` (LCC backend emitting mov-only x86 asm) → `build/rcc.wasm`
- Phase B: `cpp` (LCC's bundled C89 preprocessor) → `build/cpp.wasm`
- Phase A-2: Browser-mode (MEMFS, ES modules, embedded headers) →
  `build/browser/{cpp,rcc}.{js,wasm}` + `web/movfuscator.mjs` + `web/index.html`

Input is raw C (`.c`); output is mov-only x86 assembly text. Assembler and
linker still stay on the host (Phase C).

## Layout

```
movfuscator-wasm/
  scripts/         fetch / build / preprocess / golden-regen drivers
  patches/         local patches applied to upstream by fetch.sh
  tests/
    fixtures/      *.c programs the wasm rcc must compile
    goldens/       *.s output produced by native rcc, committed (TDD baseline)
    run.sh         node-mode pipeline test (NODERAWFS)
    browser.mjs    browser-mode pipeline test (MEMFS, via the wrapper)
  web/
    movfuscator.mjs  ES-module wrapper: compile(c: string) → Promise<string>
    index.html       in-browser demo (textarea → click → mov asm)
  Makefile         single entry point
  vendor/          (gitignored) upstream clone at pinned SHA
  build/           (gitignored) wasm artifacts
    cpp.{js,wasm}, rcc.{js,wasm}         node-mode (NODERAWFS)
    browser/cpp.{js,wasm}, rcc.{js,wasm} browser-mode (MEMFS, EXPORT_ES6)
    embed-headers/                        collected /usr/include subset
```

## Quick start

```sh
# One-time prerequisites:
#   - gcc-multilib, libc6-dev-i386  (apt)
#   - emsdk activated in $HOME/emsdk  (or EMSDK in env)

make setup                # fetch upstream + apply patches
make build-native         # build host rcc + cpp (also generates lburg outputs)
make build-wasm           # node-mode wasm artifacts (NODERAWFS)
make build-wasm-browser   # browser-mode wasm artifacts (MEMFS, ES modules)
make test                 # node pipeline vs goldens
make test-browser         # browser pipeline (via web/movfuscator.mjs) vs goldens
make serve                # python -m http.server 8080 → open /web/
```

## TDD workflow

The premise: **the wasm pipeline (cpp + rcc) on a .c fixture produces .s
byte-identical to native LCC cpp + native rcc on the same input**. This
applies to both pipelines:

| target          | pipeline                                  | runtime          |
|-----------------|-------------------------------------------|------------------|
| `make test`     | `build/cpp.js` + `build/rcc.js`           | Node (NODERAWFS) |
| `make test-browser` | `web/movfuscator.mjs` (loads `build/browser/`) | Node ESM (MEMFS, same code as in-browser) |

Any divergence is a bug. Tests are a `cmp` against committed golden files.

### In-browser demo

```sh
make build-wasm-browser
make serve
# open http://localhost:8080/web/
```

The demo (`web/index.html`) shows a textarea → "Compile →" → live mov asm.
Imports `./movfuscator.mjs` as an ES module; the wrapper instantiates fresh
`createMovCpp` / `createMovRcc` per call.

### Adding a new C fixture

1. Write `tests/fixtures/<name>.c`.
2. `make goldens` (rebuilds golden with native rcc).
3. Inspect `tests/goldens/<name>.s` — it should be valid mov-only x86 asm.
4. `make test` should now PASS for `<name>`.
5. Commit fixture + golden together.

Fixtures whose name starts with `upstream-` are copied verbatim from
`vendor/movfuscator/validation/<name>.c`. They exist to keep this
test suite aligned with the codegen surface upstream itself exercises.
`tests/fixtures/UPSTREAM_LICENSE` is the upstream BSD license retained
per its attribution clause.

### Changing the wasm build

1. Modify `scripts/build-wasm.sh` or `scripts/build-wasm-cpp.sh` (or their
   inputs).
2. `make build-wasm && make test`.
3. If a test fails: either the change is a bug (fix it), or codegen
   legitimately changed (regen goldens with `make goldens`, review the
   diff, commit). Both cases are explicit and reviewed.

### Bumping the upstream pin

1. Edit `MOVFUSCATOR_SHA` in `scripts/fetch.sh`.
2. `make distclean && make setup && make build-native && make build-wasm`.
3. `make goldens` — goldens will change to track upstream.
4. Review the diff carefully; commit.

## Why golden files in the repo?

- Tests run without needing `gcc-multilib` or the native rcc build.
- A failing test points at *exactly* the asm bytes that changed.
- Cheap regression net for refactors of the wasm build.

## Known patches

- `patches/build.sh.gcc14.patch` — demotes gcc 14's now-default
  `-Werror=implicit-int` / `-Werror=implicit-function-declaration` /
  `-Werror=int-conversion` back to warnings so LCC's K&R-era source
  compiles on modern Debian/Ubuntu hosts.
