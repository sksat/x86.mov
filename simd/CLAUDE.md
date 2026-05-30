# CLAUDE.md

**SIMD86 — Single Instruction, Multiple Decks.** A slide system where the
renderer *is* a mov-only program: the deck is an ELF (a flipbook) that
runs inside the [`movie86`](../movie86/) emulator, blitting the current
slide to the mode-13h framebuffer on each keypress. Every pixel that
reaches the screen is produced by `mov`.

## Layout

- `deck.c` — the flipbook renderer. Slides are plain image data (raw
  RGBA, one 320×200 frame each) linked in via `deck_data.s` (`.incbin`,
  generated). `main` polls input (`poll_input` → `CALL_POLL_INPUT`),
  moves a slide index (Right/Space/PageDown → next, Left/PageUp → prev,
  Home/End → ends), and `show()`s the current slide on a change. Drawing
  only on change keeps the poll loop cheap.
- `gen_deck.py` — generates placeholder slides → `deck.bin` (raw RGBA)
  + `deck_data.s`. Swap in real PNG-derived RGBA later.
- `start.s` / `stubs_llvm.s` — llvm-mov `_start` + the mov-only ABI
  stubs (`set_video_mode` / `mmap_request` / `poll_input` / `exit`) and
  the `.fb13h` framebuffer region pinned at `0xA0000`. ret-free
  (`pop ecx ; jmp ecx`) per movie86 issue #42.
- `build-deck.sh` — `gen_deck.py` → `clang -emit-llvm` → `llvm-mov-llc`
  → `as`/`ld` → `kvm2026-kansai/deck.elf`. **llvm-mov, not movfuscator**:
  llvm-mov emits ordinary `jmp/call` control flow (no SIGILL master_loop
  dispatch) so the deck runs **natively on turbo86** as well as on
  movie86. (movfuscator output can't run to completion on turbo86 yet.)
- `deck_bench.c` — bench variant that exits at the last slide, for the
  turbo86 native-speed measurement (`turbo86/runner/deck_bench_test.go`).
- `simd.mjs` — browser runtime: loads the deck into movie86, rAF step
  loop, mode-13h FB → canvas blit, `attachKeyboard` (hover-gated).
  Imports `/movie86/movie86.mjs` at runtime (the explorer cross-
  subproject pattern) so the ~110 KB wasm isn't duplicated.
- `kvm2026-kansai/index.html` — the deck viewer: **slide ⇿ movie86
  side-by-side** with a draggable divider; the slide canvas scales
  smoothly to its pane. turbo86 handover is framed as an "Acceleration
  Boost" toggle (default off).
- `index.html` — `/simd/` redirects to the single deck for now (becomes
  a deck index when there's more than one).

## Build / deploy

- `cd ../llvm-mov && make build` (Arch: `make build LLVM_CONFIG=llvm-config`)
  to get `llvm-mov-llc`, then `./build-deck.sh`. The built `deck.elf` is
  committed (like the other example ELFs; `*.elf` is force-added past
  the global gitignore) so deploy/CI need no toolchain.
- `./stage-deploy.sh` copies the page + runtime + deck into
  `../dist/simd/`. Wired into [`.github/workflows/deploy.yaml`](../.github/workflows/deploy.yaml)
  **after** the movie86 stage step (the deck page imports `/movie86/`).
- Speed: per-transition is a full-screen blit. On movie86 (wasm) that's
  ~5M guest mov/transition (~1 s in-browser); on turbo86 (native) it's
  sub-millisecond — the point of the Acceleration Boost.

## Conventions

TDD per the repo-level [CLAUDE.md](../CLAUDE.md). `test-deck.mjs` is the
e2e: load `deck.elf` in movie86, push keys, assert the framebuffer shows
the expected slide. Codegen/output changes regenerate the deck in the
same commit.
