# movfuscator-selfhost

**Can the mov-only compiler compile its own source?** i.e. can `rcc` + the
M/o/Vfuscator backend be turned into a mov-only `rcc` by itself.

This is a research subproject. It owns no toolchain of its own — it drives the
sibling [`movfuscator-wasm/`](../movfuscator-wasm/) one (its wasm `cpp` / `rcc`
/ `as` under `build/*.js`, and its vendored movfuscator + lcc sources under
`vendor/`).

## Running it

```sh
# 1. set up the sibling toolchain (once)
(cd ../movfuscator-wasm && make setup build-wasm build-wasm-as build-native)

# 2. survey: mov-compile every translation unit of rcc
bash run.sh

# 3. demo: a live mov binary actually running under movie86
bash movie86-demo.sh
```

`run.sh` feeds every translation unit that makes up `rcc` — the 28 committed
`lcc/src/*.c` front-end units plus the lburg-generated backend selectors in
`vendor/build/*.c` — through `cpp → rcc -target=x86/mov → as`. A unit counts as
compiled only when the backend prints `M/o/Vfuscation complete.` **and** `as`
emits an object. The completion banner is the only honest gate: on failure the
backend still writes a partial `.s` and exits 0, so "non-empty `.s`" means
nothing.

Two preprocessing details matter (both encoded in `run.sh`):

- **`__LCC__` is deliberately not defined.** lcc's own `c.h` is the only
  consumer of `__LCC__` in the tree, and uses it to `#define __STDC__` — which
  lcc's *own* cpp rejects as redefining a reserved builtin. The native build
  never hits this (rcc is built with gcc; lcc-cpp only ever preprocesses user
  code, which never includes `c.h`).
- **`__STRICT_ANSI__` / `_POSIX_SOURCE` are kept.** They hold glibc's headers in
  their ANSI shape. `_GNU_SOURCE` would expose GNU-extension declarations
  (`__attribute__`, `__inline`, …) that lcc's front-end cannot parse.

## State of the experiment

**35 / 36 translation units self-compile mov-only.** The lone holdout is the
mov backend itself (`mov.c`, which `#include`s `movfuscator/movfuscator.c`).
The backend is written for gcc/C99 and trips lcc's stricter C89 front-end:

| # | wall | status |
|---|------|--------|
| 1 | mid-block `extern` declarations (C99 mixed decls/statements) — the gen.c emitter hook and error.c's `errcnt` | **cleared** — hoisted to file scope by `patches/movfuscator-selfhost-c89.patch` |
| 2 | `SA_NODEFER` sits behind glibc's `_GNU_SOURCE` gate, but the front-end only parses the strict-ANSI header shape | **cleared** — same patch provides the Linux value directly |
| 3 | `movfuscator.c` forward-declares the lburg tables as `static short *_nts[];` etc. (incomplete arrays, completed later in the generated `mov.c`); lcc rejects `static` incomplete-array tentative definitions outright | **remaining** |

Wall #3 is structural: the forward declarations can't simply be deleted —
`movfuscator.c` registers the bare table symbols into the IR interface, so they
must be visible before the generated definitions. Clearing it needs an lcc
front-end leniency change *and* a rebuilt wasm `rcc`, so `mov` stays XFAIL until
the sibling toolchain is rebuilt. `run.sh` still surfaces the progress: `mov`
now advances past walls #1/#2 to the #3 diagnostic.

The patch is **codegen-neutral** for rcc, so the prebuilt `rcc.wasm` stays
valid. `run.sh` applies it (idempotently) to the sibling's vendored source. It
is intentionally **not** in `movfuscator-wasm/patches/`, so the base
movfuscator-wasm build stays pristine.

### movie86 verification

`movie86-demo.sh` proves the *live* mov pipeline (the same `cpp/rcc/as` the
survey drives) produces a binary the [`movie86`](../movie86/) emulator actually
executes:

```
prog.c ─cpp→ .i ─rcc -target=x86/mov→ .s ─as→ .o ─ld -static→ mov-only ELF (~10.8 MB)
       → run under ../movie86 → clean exit 0
```

The exit code does *not* reflect `main()`'s return value — movfuscator's `crt0`
hardcodes `exit(0)`. A clean exit 0 means "ran to completion without faulting",
which is the property milestone 3 will lean on.

## Roadmap

1. **survey** — mov-compile every rcc translation unit. *(done: 35/36)*
2. **link** — combine the `.o` into a mov-only `rcc` ELF. The link recipe
   mirrors [`../movfuscator-wasm/tests/run-multi.mjs`](../movfuscator-wasm/tests/run-multi.mjs)
   (crt0/crtf/crtd + softfloat + `-lgcc -lc -lm`). Blocked on wall #3 for a
   *fully* mov-only rcc; a hybrid (front-end mov + native `mov.o`) is linkable
   sooner.
3. **run** — execute that `rcc` (natively or in movie86) to compile a real
   program.
4. **triple** — the classic LCC self-host proof: rcc → 1rcc → 2rcc, asserting
   `1rcc` and `2rcc` are byte-identical (the upstream makefile's `triple`
   target).

Scale note: the backends are huge — `x86linux.c` alone is ~1.39M lines of `.s`
/ ~907k mov instructions / a ~10.8 MB object. A full mov-only rcc will be
enormous and slow.
