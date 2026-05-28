# CLAUDE.md

Browser bindings for the [`movie86`](../) emulator core. The Rust
crate here is a thin wasm-bindgen shim over `movie86` (no_std + alloc)
plus a host implementation that buffers `write(1/2)` and the restricted
printf wrapper into `Vec<u8>` instead of touching stdio.

## Operating model

- **Standalone Cargo workspace nested under `movie86/`.** This crate
  path-deps `../core` but is *not* a member of the `movie86` workspace
  (it declares its own `[workspace]` table) — that keeps the
  `cargo build -p movie86 --target wasm32-unknown-unknown` portability
  check on the movie86 side strictly no_std + alloc, while this crate
  is free to depend on wasm-bindgen (which pulls std).
- **wasm-bindgen pinned to 0.2.122.** Both the crate dep and the
  CLI install in CI use the same pin — the .js shim and .wasm
  metadata only match when the versions agree, so bumping is a
  three-place change (this `Cargo.toml`,
  `.github/workflows/movie86-wasm.yaml`, and the wasm-bindgen-cli
  install step in `.github/workflows/deploy.yaml`).
- **Layout matches `movfuscator-wasm/`.** Wrapper at the subproject
  root ([`movie86.mjs`](movie86.mjs)) imports
  `./build/browser/movie86_wasm.js`; samples live under
  [`samples/`](samples/). [`scripts/stage-deploy.sh`](scripts/stage-deploy.sh)
  mirrors movfuscator-wasm's stage script, but writes into
  `../../dist/movie86/` (two levels up, since this lives at
  `movie86/wasm/`).

## Host implementation

`WasmHost` reimplements (rather than reuses) `movie86-cli`'s `StdHost`
because the CLI's I/O sinks (`io::stdout()`, `io::stderr()`) aren't a
fit for an in-browser run. The semantics match:

- `int 0x80` syscalls: `write(1)`, `write(2)`, `exit(status)`. Anything
  else traps with `Fault::UnknownSyscall`. `write` returns `-EBADF`
  for fds other than 1/2, `-EFAULT` for an unreadable buffer, and the
  byte count for partial / successful writes.
- `int 0x81` libc wrappers: `exit`, `sigaction` (no-op, returns 0),
  `printf` (host-side, restricted `%s`/`%d`/`%c`/`%%` subset — `%n`
  and unknowns abort with `-1` per the smart-friend boundary the CLI
  also follows).
- Signal-handler auto-wiring: `dispatch` → SIGSEGV, `master_loop` →
  SIGILL, looked up from the ELF symbol table at run time.

The CLI's logging memory + snapshot + gdb plumbing is not ported —
they're debugger features that don't make sense in a browser tab.

## Two execution surfaces

Both ship today; pick by what you want from the call.

- **`runElf(bytes, maxSteps?)`** — one-shot. Runs to completion (or
  `MaxSteps` cap, default 50_000_000) and returns a `RunResult` with
  final stdout / stderr / exit code / fault label / step count. Used
  by the smoke test and any caller that doesn't need live state.
- **`new Vm(bytes)` + `vm.stepN(n)`** — step-driven. Lets JS drive
  the guest one (or many) instruction at a time, sampling
  `vm.regs` / `vm.eip` / `vm.steps` / `vm.haltReason` between batches
  and pulling I/O via `vm.drainStdout` / `vm.drainStderr`. Used by
  the demo's interactive Run / Step / Follow controls — see the
  follow-vs-batch loop in `index.html` for the two refresh strategies.
- **`vm.disasmAt(addr) -> DecodedInsn`** — same `movie86::decode` the
  CPU uses, but exposed so the demo can render a "next-N-instructions"
  pane with the current EIP highlighted. The decoded text is the
  Rust `Debug` form of `Insn` (e.g.
  `Mov { dst: Reg32(Ebx), src: Imm32(42) }`); a nicer Intel-syntax
  formatter is a future polish step. Tolerates short reads at the end
  of the segment so a 1-byte `ret` at the last address still decodes.

## Display strategy: follow vs periodic

The demo's "Follow execution" checkbox switches between two loop shapes.
Both yield to the browser each iteration so the **Stop** button stays
responsive.

- **Follow**: `vm.stepN(1)` + `render()` per loop. One instruction per
  frame. Slow on purpose — for watching individual moves land.
- **Periodic dump (default)**: `vm.stepN(batchSize)` per loop,
  `render()` only when `refreshMs` has elapsed. Batches keep the wasm
  boundary overhead low; the timer keeps the UI refresh-rate sane on
  long-running guests.

The user picked the rule: "naive display would be slow, so make
following all execution state optional. If not following, just dump
periodically." Don't collapse the two modes into a single render-rate
slider — they answer different questions ("show me each step" vs
"keep me roughly informed while it runs hot").

## Things future Claude shouldn't relearn

- **Don't pass init() the raw `Uint8Array`.** wasm-bindgen 0.2.x
  deprecated the positional form; the smoke test uses
  `init({ module_or_path: wasm })` and the wrapper relies on the
  default (fetch the `_bg.wasm` next to the .js). Node 18+ doesn't
  resolve `import.meta.url` to a working fetch URL for local files —
  read the wasm bytes via `fs/promises` and hand them to init
  explicitly.
- **`flatten_with_stack` returns `(FlatMemory, esp_initial)`.** Feed
  `esp_initial` into `cpu.set_reg(Reg32::Esp, esp_initial)` *before*
  the first step — without it the guest's crt0 dereferences a stale
  stack pointer and faults immediately.
- **`scan_libc_stubs` happens after memory is initialised.** Libc
  symbols only count as wrapper stubs if the bytes at their address
  read as the `CD 81` sentinel — that scan must run after the ELF's
  PT_LOAD bytes are in `mem`, not against the raw symbol table alone.
- **`make stage-deploy` in this directory only writes `../../dist/movie86/`.**
  It does **not** clear the parent `dist/`. Order in
  `.github/workflows/deploy.yaml` is: `movfuscator-wasm`'s stage-deploy
  runs first (it `rm -rf`s and rebuilds the whole `dist/`), then this
  one runs second to add `movie86/` on top. Don't reorder.
- **`Vm::read_mem` clamps to the mapped region and returns the
  intersection.** The browser memory pane wants to read a fixed-size
  window even when the start address (e.g. `eip - 16` near the top of
  a small example) is below `mem.base()` — clamping on the Rust side
  means the UI doesn't have to know the loader's layout. An empty
  return is the signal "fully outside the mapped region".

## CI

[`.github/workflows/movie86-wasm.yaml`](../../.github/workflows/movie86-wasm.yaml)
at the repo root: clippy strict against the wasm32 target, build,
stage, and a Node-driven smoke test that runs both sample ELFs through
the wasm and asserts exit code + stdout. Same `actions/cache` key shape
for `wasm-bindgen-cli` as the deploy workflow — the compiled CLI binary
is reused across the two pipelines.

The deploy workflow ([`.github/workflows/deploy.yaml`](../../.github/workflows/deploy.yaml))
runs `make build-wasm` + `make stage-deploy` for this subproject before
handing `../dist/` to wrangler.
