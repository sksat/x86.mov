# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this directory.

`movfuscator-selfhost/` is a research subproject that asks one question:
**can the mov-only compiler compile its own source?** i.e. can `rcc` + the
M/o/Vfuscator backend be turned into a mov-only `rcc` by itself.

## How it relates to the rest of the repo

This directory owns no toolchain of its own. It drives the sibling
[`movfuscator-wasm/`](../movfuscator-wasm/) one: its wasm `cpp` / `rcc` / `as`
(`../movfuscator-wasm/build/*.js`) and its vendored movfuscator + lcc sources
(`../movfuscator-wasm/vendor/`). So before running anything here, the sibling
must be set up:

```
(cd ../movfuscator-wasm && make setup build-wasm build-wasm-as)
bash run.sh
```

## What `run.sh` does

It feeds every translation unit that makes up `rcc` (the 28 committed
`lcc/src/*.c` front-end units + the lburg-generated backend selectors in
`vendor/build/*.c`) through `cpp → rcc -target=x86/mov → as`, and counts a unit
as compiled only when the backend prints `M/o/Vfuscation complete.` **and** `as`
emits an object. The completion banner is the only honest gate: on failure the
backend still writes a partial `.s` and exits 0, so "non-empty `.s`" means
nothing.

## State of the experiment

**35 / 36 translation units self-compile mov-only.** The lone holdout is the
mov backend itself (`mov.c`, which `#include`s `movfuscator/movfuscator.c`).
The backend is written for gcc/C99 and trips lcc's stricter C89 front-end:

1. **mid-block `extern` declarations** (C99 mixed declarations/statements) —
   `movfuscator.c`'s gen.c emitter hook and error.c's `errcnt`. **Cleared** by
   `patches/movfuscator-selfhost-c89.patch` (hoisted to file scope; neutral).
2. **`SA_NODEFER`** sits behind glibc's `_GNU_SOURCE` feature gate, but the
   front-end only parses under the strict-ANSI header shape. **Cleared** by the
   same patch (the Linux value is provided directly).
3. **`static short *_nts[];` etc.** — `movfuscator.c` forward-declares the
   lburg tables as incomplete arrays (completed later in the generated
   `mov.c`), and lcc rejects `static` incomplete-array tentative definitions
   outright. **Remaining wall.** Clearing it needs an lcc front-end leniency
   change *and* a rebuilt wasm `rcc`, so `mov` stays XFAIL until the sibling
   toolchain is rebuilt. (The two patched walls are still surfaced — `run.sh`
   shows `mov` advancing to this third diagnostic.)

The patch is applied (idempotently) to the sibling's vendored source by
`run.sh`. It is **not** in `movfuscator-wasm/patches/`, so the base
movfuscator-wasm build stays pristine.

## Roadmap (milestones beyond the survey)

1. **survey** — mov-compile every rcc TU. *(done: 35/36)*
2. **link** — combine the `.o` into a mov-only `rcc` ELF (link recipe mirrors
   `../movfuscator-wasm/tests/run-multi.mjs`: crt0/crtf/crtd + softfloat +
   `-lgcc -lc -lm`). Blocked on wall #3 for a *fully* mov-only rcc; a hybrid
   (front-end mov + native `mov.o`) is linkable sooner.
3. **run** — execute that `rcc` (natively or in [`movie86`](../movie86/)) to
   compile a real program.
4. **triple** — the classic LCC self-host proof: rcc → 1rcc → 2rcc and assert
   `1rcc` and `2rcc` are byte-identical (see the upstream makefile `triple`
   target).

Scale note: backends are huge — `x86linux.c` alone is ~1.39M lines of `.s` /
~907k mov instructions / a ~10.8 MB object. A full mov-only rcc will be
enormous and slow.
