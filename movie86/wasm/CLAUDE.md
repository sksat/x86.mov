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
- **wasm-bindgen pinned with `=0.2.122` (exact)**, not the usual caret.
  The CLI and crate share a schema that bumps on every patch release;
  with `Cargo.lock` gitignored, a caret `"0.2.122"` would let CI resolve
  to a newer 0.2.x while the CLI install step stays pinned, and the
  build would fail with a schema mismatch. Bumping is a three-place
  change (this `Cargo.toml`, `.github/workflows/movie86-wasm.yaml`,
  and the wasm-bindgen-cli install step in
  `.github/workflows/deploy.yaml`).
- **Layout matches `movfuscator-wasm/`.** Wrapper at the subproject
  root ([`movie86.mjs`](movie86.mjs)) imports
  `./build/browser/movie86_wasm.js`; bundled fixtures live under
  [`examples/`](examples/). [`scripts/stage-deploy.sh`](scripts/stage-deploy.sh)
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
- `int 0x10` BIOS video services: only `AH=0` (set video mode) is
  implemented — kept for the older committed canvas binaries
  (`canvas_smile.elf`, `canvas_modes.elf`, `canvas_bars.elf`,
  `canvas_mandelbrot_mov.elf`) whose sources we don't have. New
  fixtures use the mov-only ABI's `CALL_SET_VIDEO_MODE` instead, but
  the BIOS path stays so existing committed binaries don't break.
- Mov-only ABI page (`AbiHost`): `mov [0x1FFE_00NN], al/eax`
  triggers `set_video_mode` / `mmap_request` / `write` / `exit`
  without an `int` ever firing. Same constants and semantics as
  turbo86 (see `movie86::abi_host` + [turbo86/DESIGN.md
  §Mov-only ABI page](../../turbo86/DESIGN.md)). `WasmHost::abi_call`
  routes `CALL_SET_VIDEO_MODE` to the same `active_video_mode`
  field the `int 0x10` path uses, so the JS demo doesn't care which
  path the guest took. `CALL_MMAP_REQUEST` is a no-op on wasm (the
  canvas ELFs declare their FB regions as PT_LOAD and
  `flatten_with_stack` already maps them); `CALL_WRITE` mirrors
  `int 0x80 SYS_write` (`ebx`=fd, `ecx`=buf, `edx`=len, writes
  bytes-written back to `eax`); `CALL_EXIT` raises `Fault::Exit`.
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
  follow-vs-batch loop in [`runloop.mjs`](runloop.mjs) for the two
  refresh strategies (`doRun` in `index.html` just wires the DOM
  controls / Vm into it).
- **`vm.disasmAt(addr) -> DecodedInsn`** — same `movie86::decode` the
  CPU uses, but exposed so the demo can render a "next-N-instructions"
  pane with the current EIP highlighted. The decoded text is the
  `core::fmt::Display` rendering of `movie86::Insn` in AT&T (gas)
  syntax (e.g. `movl $0x2a, %ebx`), matching the flavour of `.s`
  files emitted by movfuscator and llvm-mov-llc throughout this repo.
  Jumps render their displacement as a signed offset (`jmp +0x40`,
  `call -0x5`) because `Insn::Display` doesn't know the
  instruction's own EIP; resolving the absolute target is a future
  step at the disasmAt layer, which does. Tolerates short reads at
  the end of the segment so a 1-byte `ret` at the last address still
  decodes.

## Engine handoff to local turbo86

The demo's "Send to local turbo86" button packages the live Vm state
as the canonical `movie86::context::Context` schema (same shape the
CLI's handover uses) and ships it over WebSocket to a local turbo86
process. A subsequent "Pause turbo86" + "Restore Vm from Paused"
pair brings the session back into the local Vm. Six pieces:

- **turbo86 `--allow-origin`** is what makes the cross-origin browser
  handshake actually succeed. The frontend is served from
  `https://x86.mov` or `https://<branch>.x86-mov.pages.dev` while
  turbo86 listens on `ws://127.0.0.1:1234` — those Origins must be on
  the allow-list or coder/websocket's default `Origin == Host` policy
  rejects the upgrade with 403. `cmd/turbo86/main.go`'s default already
  includes `x86.mov`, `*.x86-mov.pages.dev`, and `localhost(:*)` /
  `127.0.0.1(:*)`, so a stock `./turbo86` works with prod, every PR
  preview, and `make serve` without extra config. See turbo86
  `DESIGN.md` for the InsecureSkipVerify doctrine this replaces.

- **`vm.snapshotContext()`** — Rust-side. Builds a `ContextSnapshot`
  by combining `Regs::from_cpu(&self.cpu)` with
  `capture_sparse_regions(&self.mem, base, len)` from the core crate.
  EFLAGS is captured as 0 (movie86 doesn't model flags) but the field
  is preserved so the wire payload matches turbo86's `proto.Regs`
  byte-for-byte. Region storage is parallel `Vec<u32>` /
  `Vec<Vec<u8>>` rather than `Vec<exported_struct>` — avoids a wrapper
  type per region with its own `free`, at the cost of one extra
  cross-boundary getter call per region.
- **`movie86.mjs` wrappers** — `snapshotContext(vm)` flattens the
  Rust struct into a plain JS `{regs, regions}` (frees the wasm
  handle before returning so callers don't manage `.free()`).
  `makeLoadContextMessage(ctx, mode)` produces the JSON frame turbo86
  accepts — lowercase `type` / field names, base64-encoded `bytes`,
  matches `turbo86/proto/proto.go` exactly. `parseOutboundMessage`
  decodes the reverse direction (Stdout / Stderr / Exit / Fault /
  Paused), with `bytes` fields lifted back to `Uint8Array`.
- **`tests/turbo86_handover.mjs`** — env-gated real-turbo86 E2E.
  `TURBO86_BIN=/path/to/turbo86 node tests/turbo86_handover.mjs` runs
  against an existing binary; with the env unset, tries `go build`
  from source; with `go` also missing, skips cleanly. Verifies the
  full round-trip (exit + write + full Pause → loadContextInto loop)
  against a live turbo86 so a wire drift on either side breaks
  loudly. The Rust CLI side has its own equivalent
  (`movie86/cli/tests/handover_turbo86.rs`); the JS test pins the
  browser code path specifically.

- **`Vm::loadContext(snapshot) -> { applied, skipped }`** is the
  reverse of `snapshotContext`. Writes each region into guest
  memory, loads the regs, clears the halt cache so `stepN` re-
  evaluates from the restored EIP. Lossy by design: regions outside
  the Vm's mapped extent (typically turbo86's stack snapshot at
  0x70000000+ when the local Vm only sized memory for a small ELF)
  are silently skipped — the `skipped` count is surfaced in the
  event log so the user knows stack-resident bits were lost.

- **`loadContextInto(vm, ctx)`** is the JS wrapper. Builds a
  `ContextSnapshot` via `setRegs` + `addRegion(...)`, calls
  `vm.loadContext`, returns `{ applied, skipped }`. Used by the
  "Restore Vm from Paused" button after a turbo86 `Paused` event.

- **Unified console.** turbo86's stdout/stderr feed the SAME
  `#stdout` / `#stderr` panes the local Vm uses, prefixed
  `[turbo86] ` so the two streams are visually separable without
  splitting them spatially — the user reads one continuous output
  transcript across both engines.

- **Meta cards keep their labels but switch their data source via
  `state.engine`.** Labels are constant (`total mov` / `mov per
  sec` / `halt` / `exit` / `wall time` / `memory`); the values come
  from `state.vm` while engine == 'local' and from `turbo86.stats`
  while engine == 'turbo86'. The conceptual stretch — turbo86
  Outbound *events* stand in for *movs* — is acknowledged: turbo86
  has no instruction counter on the wire, and the alternative
  ("freeze the cards") loses the live signal the user is here for.
  Same labels on both engines keeps the project narrative
  ("everything is a mov") intact. `setEngine` flips at three
  boundaries: `doSendToTurbo86` (→ 'turbo86'), `doRun` / `doReset`
  / `doRestoreFromTurbo86` (→ 'local'). `prevRegs` / `prevEip` get
  wiped on flip so the change-highlight doesn't paint every reg
  yellow at the engine boundary.

- **Regs panel sources from the last turbo86 Paused while engine ==
  'turbo86'.** turbo86 emits regs only at Paused boundaries (Pause
  Inbound, guest fault, signal). Until the first Paused, the panel
  shows the local Vm's snapshot regs ("what got handed over") with
  a "from turbo86 Paused" note appearing once the first Paused
  arrives. `currentRegsView()` is the single source of truth — both
  `renderRegs` and any future panes that need EIP/regs should go
  through it.

- **Follow toggle drives the in-handover render cadence**, same as
  for the local Run loop:
    - `follow on`  → re-render the full UI on every Outbound event.
    - `follow off` → leave the periodic ticker (`refresh` ms input)
                     to redraw, batching event arrivals so the wasm
                     boundary overhead stays low for chatty guests.
  The WS open handler installs the `setInterval`; the close handler
  clears it.

## Display strategy: follow vs periodic

The demo's "Follow execution" checkbox switches between two display
strategies. Both yield to the browser each iteration so the **Stop**
button stays responsive.

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

**The two strategies live in ONE loop ([`runloop.mjs`](runloop.mjs)),
not two `while` shapes chosen up front.** `runLoop` re-reads the controls
(`follow` / `delay` / `batch` / `refresh`) via the injected
`readControls()` on *every* iteration, so flipping Follow — or retuning
the cadence — mid-run takes effect on the next step. The earlier code
snapshotted `follow` into a `const` at the top of `doRun` and branched
into one of two loops, which locked the strategy for the whole run; that
was the "can't toggle Follow while it's running" bug. Keep the
per-iteration read: it's the seam that makes the toggle live, and
[`tests/runloop.mjs`](tests/runloop.mjs) (pure-logic, no wasm) pins it.
The disasm/mem "follow EIP" toggles were already live because they're
read inside `render()`; this brings the master Follow toggle in line.

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
- **EFLAGS and segment registers are deliberately not surfaced**, not
  even as stubs. None of the supported instructions touch them — `mov`
  / `jmp` / `int` (trap gate, userspace-visible) / `push` / `pop` /
  `call` / `ret` are all "Flags Affected: None" per the Intel SDM,
  segment-register writes don't exist in the `Cpu` struct, and the only
  `mov sreg` form supported is `mov cs, ax` (modelled as the
  SIGILL-dispatch jump, not as a CS write). A stub display would just
  invite the next reader to wire arithmetic into the wrong place. Real
  introspection that *does* show up: `Vm::sigsegvHandler` /
  `Vm::sigillHandler` (populated by the loader from the ELF symbol
  table at load time — static post-load, but real, not a stub).
- **The framebuffer convention is memory-mapped + mov-selected, not
  syscall-driven.** `FRAMEBUFFER_MODES` in `movie86.mjs` lists
  `(modeNumber, addr, width, height)` quadruples; the guest:
    1. Sets the active mode by `mov`-ing the mode byte into the ABI
       page (`mov [0x1FFE0010], al`), routed through
       `core::abi_host::AbiHost::abi_call` to
       `WasmHost::active_video_mode`. Older committed binaries that
       use the legacy `int 0x10 / AH=0` form still work too — both
       paths land at the same `active_video_mode` field.
    2. Draws by `mov`-ing 4-byte RGBA pixels into that mode's address
       range.
  The host renders only the **active** mode's canvas each frame
  (`vm.activeVideoMode` → `modeForNumber()` → blit `vm.readMem(addr,
  byteLength)` via `putImageData`). ELFs that never set a mode get
  no canvas at all — non-canvas examples don't clutter the UI with
  empty placeholders. ELFs that want a canvas declare a second
  PT_LOAD covering the slot (`filesz=0, memsz=W*H*4`, `p_flags=RW`);
  the loader's `flatten_with_stack` already handles multiple PT_LOAD
  segments, so the only core changes needed were the `BiosHost` /
  `AbiHost` traits + the dispatch in `Cpu::step`. Addresses echo real VGA
  (mode 13h at `0xA0000`, mode 12h at `0x100000`) but the encoding is
  straight RGBA, not paletted 8bpp / 4bpp planar — "spirit of VGA",
  not exact. Hand-written canvas demos are kept feasible by run-
  length-encoding same-color pixels into one `mov eax, COLOR`
  followed by a string of 5-byte `A3 disp32` stores — see
  `examples/canvas_*.elf` generators in the commit history.
- **`BiosHost` is opt-in like `LibcHost`.** Each host (CLI's
  `StdHost`, wasm's `WasmHost`, test hosts) declares its own
  `impl BiosHost`; the trait's default `bios_call` traps with
  `Fault::UnsupportedInterrupt(0x10)`. The CLI deliberately leaves
  the default in place — it has no canvas to write to, so a
  canvas-flavoured ELF running under `movie86-cli` surfaces a fault
  the same way an unknown syscall would. WasmHost is the one place
  that actually implements `AH=0` (set mode).
- **`AbiHost` is the mov-only counterpart**, also opt-in. WasmHost's
  impl routes `CALL_SET_VIDEO_MODE` to `active_video_mode` (same
  field the `int 0x10` path writes — JS code can't tell the two
  apart), `CALL_MMAP_REQUEST` is a no-op (FB is PT_LOAD-mapped
  already), `CALL_WRITE` mirrors `int 0x80 SYS_write` byte-for-byte
  with `eax = bytes_written`, and `CALL_EXIT` raises `Fault::Exit`.
  CLI's `StdHost::abi_call` accepts `set_video_mode` (silently
  drops the mode), `exit` (raises Fault::Exit), `write` (forwards
  to host stdout/stderr), and rejects `mmap_request` (the CLI's
  FlatMemory is fixed-size at construction). Trait constants
  (`ABI_BASE`, `CALL_*`) live in `core/src/abi_host.rs` and must
  stay in lockstep with turbo86's matching numbers; the
  cross-engine contract is byte-for-byte.
- **`Vm::disasmAt` exists separately from the CPU's internal decode
  path** so the demo's disassembly pane can render rows without driving
  execution. Tolerates short reads at the end of the mapped region
  (so a 1-byte `ret` at the last address still decodes) and returns
  `None` on decode failure (e.g. EIP landed inside data) so the pane
  can stop listing instead of throwing.
- **Don't let panes resize as content varies during execution.** Both
  Disassembly (decode failures truncate rows) and Memory (`readMem`
  clipping near region edges) can return fewer rows than expected; the
  CSS locks each row's `height` and sets a fixed pane `height` /
  `min-height` so EIP movement doesn't visibly jitter the layout.
- **URL query params mirror parameter controls, not action buttons.**
  preset / follow / delay / batch / refresh / disasm-follow /
  disasm-addr / mem-follow / mem-addr / turbo86-url / turbo86-mode
  round-trip via `history.replaceState`. Reset / Step / Run / Send-
  to-turbo86 are imperative actions and intentionally stay out of the
  URL — they'd just confuse the shareable-state mental model.
- **Mandelbrot ships in two flavours from the same C source.**
  `examples/canvas_mandelbrot.elf` is `clang -O2` → `llvm-mov-llc`
  (~1.4 MB, ~90 s on a typical browser tab);
  `canvas_mandelbrot_mov.elf` is the same C through the movfuscator
  pipeline (~6.6 MB stripped, ~10 min). llvm-mov wins by ~7× in both
  step count and wall time because clang inlines `fmul`, constant-
  folds the loop bounds, and llvm-mov's CodeGen is closer to the
  metal than movfuscator's per-instruction table-lookup dispatch.
  Both are committed so the speed difference is visible side-by-
  side. The C source + `set_video_mode` stubs + a
  `build-mandelbrot.sh` that drives both pipelines live in
  `examples/sources/` for regeneration.
- **`mov r8, imm8` (B0+rb) and `mov r/m8, imm8` (C6 /0) are now
  supported** — they used to trap with `UnknownOpcode` per
  `DESIGN.md`'s "movfuscator never emits these" stance, but
  llvm-mov's CodeGen does emit them (it doesn't widen byte stores
  to 32-bit the way movfuscator does), and the Mandelbrot demo
  through that pipeline tripped both at `set_video_mode`'s
  `mov dl, 0x13` and at clang's byte-granular spill init. Filled
  the gap with unit tests pinned to those exact byte sequences.

- **Handover takes a snapshot, it does not migrate ownership.** After
  "Send to local turbo86" succeeds, the local Vm stays paused at the
  same EIP — the user can `Run` it again and the two engines diverge.
  We deliberately do not proxy turbo86's events back into the Vm; the
  semantics of "merge two divergent stdout streams" aren't worth the
  complexity for a demo. If you want a single canonical session, send
  the snapshot then `vm.free()`; that's a UI-policy decision the
  button intentionally leaves to the user.

- **Bundled examples are linked at 0x08048000 by source-level
  intent**, not by post-link patching. The fixture .s files live next
  to the .elf files in `examples/`, and [`examples/Makefile`](examples/Makefile)
  + [`examples/link.ld`](examples/link.ld) pin the link base — vaddr
  `0x08048000`, single PT_LOAD covering Ehdr + Phdr + .text, section
  headers stripped via `objcopy --strip-section-headers` so the
  committed binaries stay ~100 B instead of ~4 KB. The address
  matters for two reasons: it's the i386 SysV convention every other
  ELF in this repo (movfuscator goldens, llvm-mov outputs, real
  movfuscator binaries) also targets, and it's inside turbo86's stub
  RWX region (`[0x08048000, 0x09048000)`) so a handover Context lands
  in writable territory on the receiving side. Earlier fixtures sat
  at `0x00001000` and tripped `mmap_min_addr` + the turbo86 mapping
  range; never re-introduce that. Run `make examples` to rebuild from
  source.

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
