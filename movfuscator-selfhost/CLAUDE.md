# CLAUDE.md

Dev-process file for `movfuscator-selfhost`. Keep this short. The question this
subproject answers, the current state (which translation units self-compile,
the walls, the movie86 demo) and the roadmap live in [`README.md`](README.md) —
read that first.

## What this subproject is

A research harness that asks whether the mov-only compiler can compile its own
source. It owns no toolchain: it drives the sibling
[`movfuscator-wasm/`](../movfuscator-wasm/) wasm `cpp`/`rcc`/`as` and its
vendored sources, and runs the output under [`movie86`](../movie86/). Set the
sibling up first (`cd ../movfuscator-wasm && make setup build-wasm
build-wasm-as build-native`).

## Conventions to keep

- **The success gate is the `M/o/Vfuscation complete.` banner, never a
  non-empty `.s`.** The backend writes a partial `.s` and exits 0 on failure,
  so byte presence proves nothing. If you add checks, keep this invariant.
- **Don't edit vendored sources in place.** Backend fixes go into
  `patches/*.patch` (git-apply'd to `../movfuscator-wasm/vendor/movfuscator` by
  `run.sh`), kept out of `movfuscator-wasm/patches/` so the base build stays
  pristine. A patch must stay codegen-neutral, or the prebuilt `rcc.wasm` no
  longer matches and the survey is measuring the wrong compiler.
- **`mov` is an expected XFAIL** until wall #3 (see README) is cleared, which
  needs an lcc front-end change *and* a rebuilt wasm rcc. If `mov` ever XPASSes,
  update the `XFAIL` list rather than silencing it.
