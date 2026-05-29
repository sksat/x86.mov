# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when
working in this directory.

A Compiler-Explorer-style page for the x86.mov stack. Lets a user
edit C, pick **movfuscator-wasm** or **llvm-mov clang** as the
toolchain, inspect the produced IR (llvm-mov path only) + the mov-only
asm + the linked ELF side-by-side, then run the result in an embedded
movie86 emulator. A handover button packages the live Vm state and
ships it to a local turbo86 over WebSocket.

## Operating model

1. **Vite + React + TypeScript + Tailwind v3 + shadcn/ui.** Departure
   from the sibling subprojects' vanilla-ESM pattern — that pattern
   was fine for a single page driving one wasm wrapper; this page
   composes *three* wrappers and would have been unwieldy without a
   component model. Components live under [`src/components/`](src/components/);
   shadcn primitives are copied into [`src/components/ui/`](src/components/ui/)
   per shadcn's "you own the components" doctrine.

2. **Don't bundle the sibling wasm wrappers.** Each runs to ~tens of
   MB in shipped chunks (clang.wasm ~80 MB, the movfuscator-wasm link
   libs ~24 MB) that already deploy under their own subproject's URL
   namespace. The explorer dynamic-imports them at runtime via
   `import(/* @vite-ignore */ new URL('../movfuscator-wasm/movfuscator.mjs', import.meta.url).href)`
   so Vite's prebundler doesn't try to crawl them. See
   [`src/lib/wrappers.ts`](src/lib/wrappers.ts).

3. **The orchestration is framework-free.** The actual
   "source → IR → asm → obj → ELF" pipeline lives in
   [`explorer.mjs`](explorer.mjs) at the subproject root — pure ESM,
   dependency-injected so the unit suite ([`tests/unit.test.mjs`](tests/unit.test.mjs))
   can test it without spinning up clang.wasm. The TS facade
   [`src/lib/compiler.ts`](src/lib/compiler.ts) wires the real wrappers
   in for production calls. **Don't fork the algorithm into the React
   layer** — update `explorer.mjs` instead, the suite gates on it.

4. **Reuse, don't extend, the parent subprojects.** The embedded
   movie86 panes (Registers, Disassembly, Memory, Canvas, Console)
   wrap the existing `movie86.mjs` Vm API the same way
   `movie86/wasm/index.html` does — they don't import from
   `movie86/core` or duplicate the wasm-bindgen layer. If a behaviour
   gap shows up (e.g. the Disassembly pane wants Intel-syntax instead
   of Rust Debug format), fix it in the parent subproject's `Insn`
   formatter, not by reformatting strings here.

## Pipeline

```
        ┌── movfuscator ────────────────────────┐
        │   compile() → .s                      │
.c  ────┤                                       ├──→ as.wasm ─→ .o ─→ ld.wasm ─→ ELF32
        │                                       │
        └── llvm-mov: clang.wasm → .ll          │
            llvm-mov-llc.wasm → .s (mov-only)   │
            ────────────────────────────────────┘
```

Both pipelines share the `.s → .o → ELF` tail (binutils-as.wasm /
ld.wasm from `movfuscator-wasm/`). One link-libs bundle, one assembler
artefact — no need to ship binutils twice.

## Layout

```
explorer/
  package.json
  vite.config.ts                Vite + React + outDir=../dist/explorer
  tsconfig.{json,app.json,node.json}
  tailwind.config.js            shadcn-aligned tokens
  postcss.config.js
  index.html                    Vite entry
  explorer.mjs                  ← framework-free orchestration (tested in Node)
  src/
    main.tsx
    App.tsx                     Top-level layout / state owner
    index.css                   shadcn CSS variables + tailwind directives
    lib/
      compiler.ts               TS facade over explorer.mjs
      wrappers.ts               Runtime dynamic loaders for sibling wasm modules
      utils.ts                  cn(), hex helpers
      presets.ts                Bundled C snippets
    hooks/
      useMovie86Vm.ts           Vm lifecycle + Run/Step/Reset state
    components/
      ui/                       shadcn primitives (Button, Card, Select, …)
      SourceEditor.tsx          CodeMirror + cpp lang
      CodeViewer.tsx            CodeMirror read-only + gas / llvm-IR mode
      CompilerControls.tsx
      CompileOutput.tsx
      ElfSummary.tsx
      Turbo86Handover.tsx
      movie86/
        Movie86Panel.tsx
        Registers.tsx
        Disassembly.tsx
        Memory.tsx
        Canvas.tsx
        Console.tsx
  tests/
    unit.test.mjs               Node --test: orchestration surface
    e2e/structure.spec.ts       Playwright: structural smoke
  scripts/
    stage-deploy.sh
  Makefile
```

## Test gates (TDD order)

| target | what it asserts | dependency |
|---|---|---|
| `make test-unit` | `explorer.mjs` orchestration: compiler dispatch, normalized result shape, error path | none |
| `make typecheck` | TS strict + erasable-syntax passes | `node_modules` |
| `make build` | Vite production build emits `../dist/explorer/` | `node_modules` |
| `make test-e2e` | Playwright structural smoke against `vite preview` | `make build` |
| (future) | full compile + run E2E driving the real wasm wrappers | sibling `make build`s |

The full-pipeline E2E (compile-run-handover round-trip with the actual
clang.wasm etc.) is intentionally not gated by default — those
artefacts are produced by the sibling subprojects' own CI workflows
and copied into `dist/` at deploy time. Local dev that needs them
goes through `make -C ../movfuscator-wasm build-wasm-browser` /
`make -C ../movie86/wasm build-wasm` / `make -C ../llvm-mov/wasm build`
first.

## Known limitations

- **`Compile` → `movie86 Run` doesn't round-trip yet.** Both in-browser
  pipelines (movfuscator-wasm and llvm-mov clang) go through binutils-
  wasm `ld` with `-dynamic-linker /lib/ld-linux.so.2`, so the produced
  ELF is **dynamically linked**. movie86 only loads **static** ELFs
  (PT_INTERP / PT_DYNAMIC → `LoadError: DynamicLinkingUnsupported` at
  `Vm::new`). The explorer surfaces this clearly in the Movie86Panel
  error banner. To actually run / hand-off, pick one of the pre-built
  static fixtures from the "Example fixture" dropdown (sourced from
  `movie86/wasm/examples/*.elf`) or upload your own static ELF. A
  follow-up will add a `static: true` option to
  `movfuscator-wasm/movfuscator.mjs`'s `link()` so the in-browser
  pipeline can emit movie86-runnable ELFs directly. Until then the
  compile path is for **inspection** (IR / asm / ELF hex / disasm)
  and the run / handover path is for the example fixtures.

## Things future Claude shouldn't relearn

- **Don't bundle the sibling wrappers** (see Operating model #2). If
  TypeScript starts complaining that the runtime import URL can't be
  resolved, the fix is to keep the dynamic `import()` and refine the
  TS type via the `WrapperRecord` interfaces in
  [`src/lib/wrappers.ts`](src/lib/wrappers.ts) — *not* to add a static
  `import` of the .mjs from React.
- **`base: './'` in vite.config.** Cloudflare Pages serves the same
  bundle at both `https://x86.mov/explorer/` and at PR-preview
  subpaths (`<branch>.x86-mov.pages.dev/explorer/`); a hard-coded
  `/explorer/` `base` breaks the preview deploys.
- **Dynamic disasm text is whatever movie86 returns.** Today: Rust's
  `Debug` (`Mov { dst: Reg32(Ebx), src: Imm32(42) }`). The follow-up
  branch `movie86/disasm-display` swaps that for AT&T syntax in
  `movie86/core`'s `Display` for `Insn`. The explorer renders the
  text verbatim — no string post-processing here.
- **Run `cargo fmt` is not us, but `npm run typecheck` is.** CI gates
  on `tsc -b --noEmit`; local dev should run `make typecheck` before
  pushing.
- **Stage-deploy order.** `.github/workflows/deploy.yaml` runs
  movfuscator-wasm → movie86/wasm → llvm-mov/wasm → explorer.
  movfuscator-wasm's step `rm -rf`s the parent `dist/` and rebuilds;
  the other three layer in. Don't reorder; the explorer step writes
  *only* `dist/explorer/` and assumes the sibling subdirs are already
  there.

## CI

Planned `.github/workflows/explorer.yaml`:
- typecheck
- unit tests (Node --test)
- vite build
- playwright structural smoke against the preview server

Deploy integration lives in
[`.github/workflows/deploy.yaml`](../.github/workflows/deploy.yaml) —
adds a `make build` + `make stage-deploy` step after the three sibling
subprojects'.
