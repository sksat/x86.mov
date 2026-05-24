# movfuscator → WebAssembly (Phase A)

WebAssembly port of [movfuscator](https://github.com/xoreaxeaxeax/movfuscator)'s
code generator (`rcc`), so that compiling C to mov-only x86 assembly can run in
any wasm runtime — including a browser tab on [x86.mov](../index.html).

**Phase A scope**: only `rcc` (the LCC backend that emits mov-only asm) is
ported. Input is preprocessed C (`.i`); output is mov-only x86 assembly text.
The preprocessor (`cpp`), assembler, and linker stay on the host.

## Layout

```
wasm/
  scripts/         fetch / build / preprocess / golden-regen drivers
  patches/         local patches applied to upstream by fetch.sh
  tests/
    fixtures/      *.c programs the wasm rcc must compile
    goldens/       *.s output produced by native rcc, committed (TDD baseline)
    run.sh         runs wasm rcc on each fixture, asserts byte-identical
  Makefile         single entry point
  vendor/          (gitignored) upstream clone at pinned SHA
  build/           (gitignored) wasm artifacts (rcc.js + rcc.wasm)
```

## Quick start

```sh
# One-time prerequisites:
#   - gcc-multilib, libc6-dev-i386  (apt)
#   - emsdk activated in $HOME/emsdk  (or EMSDK in env)

make setup         # fetch upstream + apply patches
make build-native  # build host rcc (also generates lburg outputs)
make build-wasm    # build rcc.js + rcc.wasm
make test          # assert wasm output == committed goldens
```

## TDD workflow

The premise: **wasm rcc must produce byte-identical output to native rcc**.
Any divergence is a bug. Tests are a `cmp` against committed golden files.

### Adding a new C fixture

1. Write `tests/fixtures/<name>.c`.
2. `make goldens` (rebuilds golden with native rcc).
3. Inspect `tests/goldens/<name>.s` — it should be valid mov-only x86 asm.
4. `make test` should now PASS for `<name>`.
5. Commit fixture + golden together.

### Changing the wasm build

1. Modify `scripts/build-wasm.sh` (or its inputs).
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
