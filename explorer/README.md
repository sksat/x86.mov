# x86.mov Explorer

A Compiler-Explorer-style page for the x86.mov stack. Pick a compiler
(movfuscator-wasm or llvm-mov clang), edit C source, watch IR + asm
+ ELF land side-by-side, then run the result in an embedded movie86
emulator — all client-side. A handover button ships the live Vm to a
local turbo86 over WebSocket so the same program can keep running
under ptrace on the native CPU.

Live: <https://x86.mov/explorer/>

## Stack

- **Vite + React + TypeScript** for the page shell
- **Tailwind v3 + shadcn/ui** for the components
- **CodeMirror v6** for the editor + read-only viewers (cpp / gas /
  LLVM IR languages)
- Sibling subprojects loaded at runtime via dynamic import:
  - `../movfuscator-wasm/` — LCC + mov backend → `.s`
  - `../llvm-mov/wasm/` — clang.wasm + llvm-mov-llc.wasm
  - `../movie86/wasm/` — Rust no_std emulator + handover wrapper

## Quick start

```
make dev       # vite dev server (uses sibling subprojects' bytes if present)
make build     # vite build → ../dist/explorer/
make test      # node --test on the orchestration module
make test-e2e  # playwright structural smoke against vite preview
```

Each of the sibling subprojects has its own build prerequisites; see
their `README.md`s. You can run the Explorer's UI shell without
having built them — compile will fail at runtime with a clear error,
but the page renders and the editor / panes work for inspection.

## See also

- [`CLAUDE.md`](CLAUDE.md) — architecture, conventions, gotchas.
- [`../movfuscator-wasm/`](../movfuscator-wasm/) — the C → mov-only
  pipeline this page wraps.
- [`../llvm-mov/wasm/`](../llvm-mov/wasm/) — the LLVM 22-based
  pipeline alternative.
- [`../movie86/wasm/`](../movie86/wasm/) — the emulator + the source
  of truth for the handover wire format.
