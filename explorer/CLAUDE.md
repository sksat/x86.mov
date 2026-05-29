# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when
working in this directory.

A Compiler-Explorer-style page for the x86.mov stack. Lets a user
edit C, pick **movfuscator-wasm** or **llvm-mov clang** as the
toolchain, inspect the produced IR (llvm-mov path only) + the mov-only
asm + the linked ELF side-by-side, then run the result in an embedded
movie86 emulator. A segmented **execution-backend selector** (movie86 |
turbo86) chooses where the program runs: picking turbo86 while running
forward-hands the live Vm state to a local turbo86 over WebSocket;
switching back to movie86 while running reverse-hands it home (Pause →
Paused → loadContext). Picking while stopped just records the choice;
the next Run acts on it.

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

   The same split applies to the **execution-backend selector**: the
   movie86-vs-turbo86 switch *rules* (defer-vs-handover, forward vs
   reverse) live in [`backend.mjs`](backend.mjs) and are pinned by
   [`tests/backend.test.mjs`](tests/backend.test.mjs);
   [`src/hooks/useExecBackend.ts`](src/hooks/useExecBackend.ts) only
   *dispatches* those decisions onto the two concrete backends
   (`useMovie86Vm` + `useTurbo86Session`). Don't bake the rule table
   into a component.

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
  explorer.mjs                  ← framework-free compile orchestration (tested in Node)
  explorer.d.mts                sidecar TS types for explorer.mjs
  runloop.mjs                   ← framework-free Run loop (tested in Node)
  runloop.d.mts                 sidecar TS types for runloop.mjs
  backend.mjs                   ← framework-free backend-selector decisions (tested in Node)
  backend.d.mts                 sidecar TS types for backend.mjs
  src/
    main.tsx
    App.tsx                     Top-level layout / state owner
    index.css                   shadcn CSS variables + tailwind directives
    lib/
      compiler.ts               TS facade over explorer.mjs
      backend.ts                TS facade over backend.mjs
      wrappers.ts               Runtime dynamic loaders for sibling wasm modules
      utils.ts                  cn(), hex helpers
      presets.ts                Bundled C snippets
    hooks/
      useMovie86Vm.ts           movie86 Vm lifecycle + Run/Step/Reset/Follow state
      useTurbo86Session.ts      persistent turbo86 WebSocket (forward + reverse handover)
      useExecBackend.ts         coordinator: backend.mjs decisions → side effects
    components/
      ui/                       shadcn primitives (Button, Card, Select, …)
      SourceEditor.tsx          CodeMirror + cpp lang
      CodeViewer.tsx            CodeMirror read-only + gas / llvm-IR mode
      CompilerControls.tsx
      CompileOutput.tsx
      ElfSummary.tsx
      BackendSelector.tsx       segmented movie86 | turbo86 toggle
      Turbo86Controls.tsx       turbo86 URL / mode / status strip
      movie86/
        Movie86Panel.tsx
        Registers.tsx
        Disassembly.tsx
        Memory.tsx
        Canvas.tsx
        Console.tsx
  tests/
    unit.test.mjs               Node --test: compile orchestration surface
    runloop.test.mjs            Node --test: Run-loop / live Follow toggle
    backend.test.mjs            Node --test: backend-selector decision rules
    e2e/structure.spec.ts       Playwright: structural smoke
  scripts/
    stage-deploy.sh
  Makefile
```

## Test gates (TDD order)

| target | what it asserts | dependency |
|---|---|---|
| `make test-unit` | `explorer.mjs` orchestration + `backend.mjs` selector rules (compiler dispatch, normalized result shape, error path; backend switch decision table) | none |
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

## Product intent

The explorer is fundamentally a **compile → run** tool: the user
edits C, clicks Compile, and the produced binary auto-loads into the
embedded movie86 emulator so they can Step / Run / hand off to
turbo86. Everything else is supporting cast.

There is exactly one optional escape hatch: the **Upload** button in
the Movie86 panel header (`data-testid="elf-upload"`), for the case
where the user wants to drop in an arbitrary static ELF instead of
the just-compiled one. **Do not** reintroduce pre-built "example"
preset dropdowns — that would push the page's intent away from "run
what you compiled".

## Known limitations

- **llvm-mov path compiles → runs end-to-end.** With the static-link
  primitive from PR #39 (`link({ static: true, runtime: 'none' })`)
  the explorer's llvm-mov pipeline now links its output through
  `_start.o + <user>.o` (no movfuscator CRT, no PT_INTERP / PT_DYNAMIC)
  and the freshly-compiled ELF auto-loads into the embedded movie86.
  Click Run → the mov-only ABI exit at the end of `_start` raises
  `Fault::Exit(eax)` and the status row shows the exit code. The
  Movie86Panel's red banner only fires now for the movfuscator path
  (see next bullet).
- **movfuscator path still surfaces a load-error banner.** The
  movfuscator pipeline keeps the historical dynamic / movfuscator-CRT
  link recipe because flipping it to `runtime: 'movfuscator', static:
  true` is *necessary* but not sufficient: movie86 then accepts the
  ELF but trips on an `Unmapped(0x88049309)` inside `master_loop`'s
  dispatch table — a separate movie86 runtime investigation that's
  tracked independently. Until that lands, the explorer keeps the
  movfuscator path dynamic and surfaces the
  `DynamicLinkingUnsupported` banner so the user understands the gap
  rather than staring at a fault label they can't act on. The
  inspection panes (IR / asm / ELF hex / disasm) keep working
  regardless.
- The optional **Upload** button still works for either path — useful
  for inspecting / running a static ELF the explorer didn't produce.

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
- **The Follow toggle must stay *live* (re-read each loop iteration).**
  The Movie86 panel has a "Follow" checkbox + step-delay input
  (`vm-follow` / `vm-delay`) that switch between one-step-per-frame and
  the batched periodic dump — same two strategies as the movie86 demo.
  The loop lives in [`runloop.mjs`](runloop.mjs) (own copy, *not*
  imported from `movie86/wasm/` — the subproject keeps siblings at
  arm's length; we mirror its tested shape instead and pin it in
  [`tests/runloop.test.mjs`](tests/runloop.test.mjs)). `useMovie86Vm`
  mirrors `follow` / `delayMs` into refs so `readControls()` sees the
  *current* value every iteration — that's what lets the toggle take
  effect mid-run. If you ever capture `follow` once into the `run()`
  closure, the toggle silently goes back to "only applies on the next
  Run" — that was the original movie86 bug. `batchSize` / `refreshMs`
  stay fixed per run (passed as `run()` opts); only follow/delay are
  live.
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
