# movfuscator → WebAssembly

WebAssembly port of [movfuscator](https://github.com/xoreaxeaxeax/movfuscator)'s
code generator and preprocessor, plus the GNU assembler and linker — so the
entire `.c → mov-only ELF32 executable` pipeline can run in any wasm runtime,
including a browser tab on [x86.mov](../index.html).

**Scope**:
- Phase A: `rcc` (LCC backend emitting mov-only x86 asm) → `build/rcc.wasm`
- Phase B: `cpp` (LCC's bundled C89 preprocessor) → `build/cpp.wasm`
- Phase A-2: Browser-mode (MEMFS, ES modules, embedded headers) →
  `build/browser/{cpp,rcc}.{js,wasm}` + `web/movfuscator.mjs` + `web/index.html`
- Phase C: `as` (GNU binutils 2.44 gas, i386 target) → `build/as.{js,wasm}`,
  byte-identical ELF32 .o vs host /usr/bin/as
- Phase D: `ld` (GNU binutils 2.44, same source tree as gas) →
  `build/ld.{js,wasm}`, byte-identical ELF32 executable vs host /usr/bin/ld
- Phase E: Browser-mode `as` and `ld` (re-linked with MEMFS / ES6
  modules) → `build/browser/{as,ld}.{js,wasm}`. The wrapper exposes
  `assemble()` and `link()`; the demo gains **Download .o** and
  **Download ELF** buttons. Link inputs (crt, softfloat32, libc, libm,
  libgcc, ld-linux.so.2 — ~24 MB) live under `web/lib/` and are
  lazy-fetched the first time the user clicks Download ELF.

`.c → wasm cpp → .i → wasm rcc → .s → wasm as → .o → wasm ld → ELF`. The
output is a real Linux x86_32 binary; on a host with multilib it runs
unmodified.

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
    movfuscator.mjs  ES-module wrapper: compile / assemble / link
    index.html       in-browser demo (Compile, Download .o, Download ELF)
    md5.c, md5.h     md5 preset source (used by the demo's preset selector)
    lib/             (gitignored) crt + libc + libgcc bundle for Download ELF
  Makefile         single entry point
  vendor/          (gitignored) upstream clone at pinned SHA
  build/           (gitignored) wasm artifacts
    cpp.{js,wasm}, rcc.{js,wasm}              node-mode (NODERAWFS)
    as.{js,wasm}, ld.{js,wasm}                node-mode binutils
    browser/cpp.{js,wasm}, rcc.{js,wasm}      browser cpp/rcc (MEMFS, ES6)
    browser/as.{js,wasm}, ld.{js,wasm}        browser binutils (MEMFS, ES6)
    embed-headers/                            collected /usr/include subset
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

## Benchmarks

`make bench` runs `hyperfine` and `/usr/bin/time -v` over the full
**`.c → ELF`** pipeline (cpp + rcc + as + ld) three ways and writes a
markdown report to [bench/results.md](bench/results.md). On a Debian 13 /
x86_64 Beelink Mini S host (snapshot in the report):

| fixture           | asm lines | native | wasm-browser | time ratio | wasm-browser RSS |
|-------------------|----------:|-------:|-------------:|-----------:|-----------------:|
| `return42`        |       712 | 140 ms |    510 ms    |    3.6×    |        186 MB |
| `hello`           |       979 | 148 ms |    552 ms    |    3.7×    |        197 MB |
| `upstream-prime`  |     9,994 | 160 ms |    597 ms    |    3.7×    |        199 MB |
| `upstream-hanoi`  |    16,766 | 170 ms |    638 ms    |    3.7×    |        202 MB |
| `upstream-mandelbrot` | 12,179 | 166 ms |  597 ms    |    3.6×    |        187 MB |
| `upstream-mersenne` | 33,841 | 174 ms |    625 ms    |    3.6×    |        195 MB |
| `upstream-ray3`   |    69,554 | 207 ms |    730 ms    |    3.5×    |        201 MB |
| `upstream-md5`    |   124,521 | 285 ms |    896 ms    |  **3.2×**  |        241 MB |

Findings worth noting:

- **wasm-browser beats wasm-node** because the wasm-node driver spawns
  four Node processes per fixture (`cpp ; rcc ; as ; ld`) while the
  browser wrapper stays in one process and re-uses each tool's Module
  instance.
- **The link step dominates the floor** — `ld` mmaps `crtd.o` (~15 MB
  of mov tables) on every link, which is why even an empty `return 0`
  needs ~140 ms natively. That fixed cost shrinks the wasm:native
  ratio compared to the cpp+rcc-only bench (which was 25× for return42);
  the wasm slowdown is now a fairly flat 3.5×–3.7× across fixture sizes.
- **Peak RSS**: native pipeline hits ~66 MB (mostly the linker holding
  crtd.o and the libs); wasm-browser climbs to ~200 MB for typical
  fixtures and ~240 MB for md5 because cpp.wasm + rcc.wasm + as.wasm +
  ld.wasm + their MEMFS images are all resident in one Node process.
  Heavy for a tab but still under what a typical SPA uses.
- **md5 finishes in 0.9 s end-to-end via wasm-browser** — including
  cpp, rcc, as and ld. The browser's Compile / Download .o / Download
  ELF buttons show the same individual stage timings live.

Override the fixture set:
```sh
BENCH_FIXTURES="return42 upstream-ray3" make bench
```

## Why golden files in the repo?

- Tests run without needing `gcc-multilib` or the native rcc build.
- A failing test points at *exactly* the asm bytes that changed.
- Cheap regression net for refactors of the wasm build.

## Known patches

- `patches/build.sh.gcc14.patch` — demotes gcc 14's now-default
  `-Werror=implicit-int` / `-Werror=implicit-function-declaration` /
  `-Werror=int-conversion` back to warnings so LCC's K&R-era source
  compiles on modern Debian/Ubuntu hosts.
- `patches/binutils-2.44/01-libiberty-psignal-const.patch` — makes
  libiberty's fallback `psignal` definition take `const char *`, since
  Emscripten's `<signal.h>` declares it that way.

## Phase C+D: wasm as and ld

`scripts/build-wasm-as.sh` builds both `as` and `ld` from a single
binutils 2.44 source tree, targeting i386-linux as wasm artifacts. The
byte-identical safety net extends through assembly and linking:

- `make test-as`: for every fixture, `wasm-as < .s > .o` matches the
  host `as` byte-for-byte.
- `make test-ld`: for every fixture, `wasm-ld` linking that same .o
  plus crt0/crtf/crtd + softfloat32 + libc/libm/libgcc references
  produces an ELF32 executable byte-identical to host `/usr/bin/ld`'s
  output.

The resulting ELF is a real Linux x86_32 binary: it runs unmodified on
a multilib host. (Verified: wasm-linked `upstream-hello.elf` prints
"Hello, world!" — and its bytes match host-linked output to the
hash.)

The build needs four things modern binutils doesn't give you cleanly
in an Emscripten cross-compile:

1. `libiberty`'s fallback `psignal` definition signature clashes with
   Emscripten's `<signal.h>`. Patched.
2. `bfd/doc/chew` (binutils' own .texi generator) is a host build tool.
   `emconfigure` compiles it as wasm by default and then the Makefile
   tries to run it as a host executable. Rebuilt with the system `cc`
   after configure.
3. `-mx86-used-note=no` (passed to as) keeps the assembler from
   emitting an `.note.gnu.property` ELF section that modern binutils
   includes by default — necessary on both sides (host and wasm) to
   stay byte-identical.
4. `--hash-style=gnu` (passed to ld) avoids the legacy SysV `.hash`
   section the cross-built ld defaults to including, matching the
   host's Debian-default `gnu`.

A clean build, from `make distclean` to `make test-ld`, takes ~12 min
on a modern host. The resulting `build/as.wasm` is ~2 MB and
`build/ld.wasm` is ~8 MB (the latter is bigger because the build keeps
DWARF debug info that emcc warns it can't fully optimize through —
fine for now).
