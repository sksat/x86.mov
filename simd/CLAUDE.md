# CLAUDE.md

**SIMD86 — Single Instruction, Multiple Decks.** A slide system where the
renderer *is* a mov-only program: the deck is an ELF (a flipbook) that
runs inside the [`movie86`](../movie86/) emulator, blitting the current
slide to the framebuffer on each keypress. Every pixel that reaches the
screen is produced by `mov`. The narrative: it's slow in the browser
(movie86, wasm), so hand off to a local **turbo86** for native speed —
framed in the UI as an "acceleration boost".

## Deck = config + images → memory image

A deck is authored as a spec, not code:

- `kvm2026-kansai/deck.toml` — slides top to bottom, each with an `image`
  (a PNG path, or `color:RRGGBB` placeholder) and a `resolution`
  (`320x200` / `640x480` / `640x350` / `800x600` — must be a movie86
  framebuffer mode).
- `gen_deck.py deck.toml -o DIR` — the converter: turns the spec + images
  into the **guest memory image** `deck.bin` (raw RGBA, one frame per
  slide, concatenated) plus `deck_data.s`, a slide table the renderer
  indexes (`n_slides` + `slide_mode/addr/npix/off` `.long[]` arrays).
  Resolution → (mode byte, FB guest address) via `MODES`, which must
  match `FRAMEBUFFER_MODES` in `movie86.mjs`.
- `deck.c` — the mov-only flipbook. Polls input, moves a slide index
  (Right/Space/PageDown → next, Left/PageUp → prev, Home/End → ends), and
  on a change **re-issues `set_video_mode` only when the resolution
  differs** between slides, then blits. So a deck can start light
  (320x200) and bump to a heavier mode mid-deck — the heavy blit is where
  the boost earns its keep.
- `start.s` / `stubs_llvm.s` — llvm-mov `_start` + the mov-only ABI stubs
  (`set_video_mode` / `mmap_request` / `poll_input` / `exit`) and one
  `.fbNNN` `@nobits` framebuffer region per mode the deck uses, pinned to
  the mode's guest address by `--section-start` in `build-deck.sh`. Add a
  section here (+ a `--section-start` there + a `MODES` entry in
  gen_deck) when a deck introduces a new mode.
- `build-deck.sh [OUT] [DECK_TOML] [SRC_C]` — `gen_deck.py` →
  `clang -emit-llvm` → `llvm-mov-llc` → `as`/`ld` → `deck.elf`.
  **llvm-mov, not movfuscator**: llvm-mov emits ordinary `jmp/call`
  control flow (no SIGILL master_loop) so the deck runs **natively on
  turbo86** as well as on movie86. The built `deck.elf` is committed
  (like the other example ELFs; `*.elf` is force-added past the global
  gitignore) so deploy/CI need no toolchain.
- `deck_bench.c` — bench variant that exits at the last slide, for the
  turbo86 native-speed measurement (`turbo86/runner/deck_bench_test.go`).

## Browser

- `simd.mjs` — deck runtime: loads the deck into movie86, rAF step loop,
  active-mode FB → canvas blit, `attachKeyboard` (hover-gated). Imports
  `/movie86/movie86.mjs` at runtime (the explorer cross-subproject
  pattern) so the wasm isn't duplicated.
- `kvm2026-kansai/index.html` — the deck viewer: **slide ⇿ movie86
  side-by-side**, draggable divider, the slide canvas scales smoothly to
  its pane. The movie86 pane **minimizes on click** (collapses to a bar
  but keeps showing mov count + mov/sec). The "acceleration boost" button
  (`acceleration-boost.png`) hands the session off to turbo86 (default
  off; wiring follows the movie86 demo's handover + WS KeyInput path).
- `index.html` — `/simd/` redirects to the single deck for now (becomes a
  deck index when there's more than one).

## Deploy

`stage-deploy.sh` copies the page + runtime + deck + boost image into
`../dist/simd/`, wired into [`.github/workflows/deploy.yaml`](../.github/workflows/deploy.yaml)
**after** the movie86 stage step (the deck page imports `/movie86/`).

Speed: per-transition is a full-screen blit. On movie86 (wasm) the
800x600 slides are ~tens of millions of guest mov each (seconds); on
turbo86 (native) sub-millisecond — the point of the boost.

## Conventions

TDD per the repo-level [CLAUDE.md](../CLAUDE.md). `test-deck.mjs` is the
e2e: load `deck.elf` in movie86, push keys, assert the framebuffer shows
the expected slide (incl. the mid-deck resolution change). Regenerate the
deck in the same commit as a deck.toml / source change.
