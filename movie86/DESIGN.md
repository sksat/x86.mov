# DESIGN.md

Architecture, decisions, and the investigation notes behind movie86.
`CLAUDE.md` next door is the process / TDD / workflow doc — read this
file when you're touching code and need to understand *why* something
is shaped the way it is.

`movie86` is a Rust `no_std` emulator for mov-heavy ELF32 i386
binaries — the output of [movfuscator-wasm](../movfuscator-wasm/) and
the planned mov-only [LLVM backend](../llvm-mov/) (when it lands). The
name is mov + ie: watching a mov-only binary execute is the joke.

## Layout

Two-crate Cargo workspace at this directory.

- [`core/`](core/) — crate `movie86`, `no_std` + `alloc`. Library only. Decoder, CPU, memory abstraction, syscall trait, ELF loader. This is the artifact that will eventually build to `wasm32-unknown-unknown` and run in a browser. (Path is `core/`; the crate name dropped the `-core` suffix to match the `movie86` brand.)
- [`cli/`](cli/) — crate `movie86-cli`, `std`. Provides `lib.rs` (the `run_elf` entry point + `StdHost` that wires Linux i386 syscalls to the surrounding process) **and** a thin `bin` target at [`cli/src/main.rs`](cli/src/main.rs). The library half exists specifically so end-to-end tests in [`cli/tests/`](cli/tests/) can drive the same code path the binary uses without spawning a subprocess.

Run the bin with `cargo run -p movie86-cli -- path/to/file.elf`; exit status is the guest's `exit(2)` status, low 8 bits, with `1` for any fault.

## Architectural decisions (don't undo without reading the why)

- **Decoder and execution are separate.** [`decode::decode(&[u8]) -> Result<(Insn, u8), Fault>`](core/src/decode.rs) is a pure function over bytes. [`Cpu::step()`](core/src/cpu.rs) calls it. Same decoder will host a future disassembler / tracer / coverage tool; fusing it into `step` would make those reuse cases hard.

- **Memory is a trait, not a flat `Vec<u8>`.** [`Memory`](core/src/mem.rs) abstracts the guest address space; the first impl ([`FlatMemory`](core/src/mem.rs)) is a single contiguous region. Multi-region / paged variants can slot in without changing the loader or CPU. `FlatMemory::new_zeroed` **rejects regions whose end runs past `0xffff_ffff`** at construction — the guest space is `u32`, so a region past the top would let later accesses silently wrap.

- **Syscalls trap unless the host knows them.** The [`SysHost`](core/src/syscall.rs) trait is the only way `int 0x80` does anything useful. There is intentionally **no default no-op handler** — silent success on unknown syscall numbers hides bugs. Tests use either `PanicHost` (asserts no syscall happens) or a `RecordingHost` (captures the args).

- **Two host ABIs, separate traits.** `int 0x80` is Linux syscalls (`SysHost`, register-based). `int 0x81` is the host-wrapper libc ABI (`LibcHost`, cdecl on the stack). Smart-friend's review pinned mixing the two as the wrong boundary — they're different ABIs, and a future wasm host plugs the same trait pair in.

- **`step()` returns the next `eip` from `execute`.** Most instructions return `next_eip_default` (eip + insn-len); `jmp rel32` returns `next_eip_default + disp` — i.e. relative to the *end* of the jmp, per Intel SDM. Don't add a length to eip in `step` after `execute` returns: that's already baked into the default.

- **Operand width is encoded in the operand variant.** [`Operand::Reg32(_)` / `Mem32(_)` / ...](core/src/insn.rs) is the typed way of saying "32-bit operand" — `Mov { dst: Reg8(_), src: Mem32(_) }` is unrepresentable. The decoder is responsible for emitting matching widths; mismatched widths trap as `UnimplementedMov`.

## Scope (and what's NOT in scope)

In scope: the instructions movfuscator + the planned mov-only LLVM backend actually emit. That's mov-heavy (all `mov` widths, ModR/M, SIB, the 0x66 operand-size prefix), plus `jmp rel32` (E9), `jmp r/m32` (FF /4), `int N` (CD ib — dispatches by vector), `push`/`pop` (50+rd / 58+rd), and `call rel32` / `ret near` (E8 / C3). Linux i386 syscalls: at minimum `exit(1)` and `write(4)`.

**Deliberately not implemented even though they're valid x86:**

- `mov r8, imm8` (B0+rb), `mov r/m8, imm8` (C6 /0): **now supported** — `llvm-mov`'s codegen emits these for byte-granular stores (it doesn't widen byte moves to 32-bit the way movfuscator does), and the canvas Mandelbrot demo through that pipeline tripped both. Filled the gap per the original "add when it actually fires" stance, with unit tests pinned to the byte sequences that surfaced them (`mov dl, 0x13` from `set_video_mode` and `mov BYTE PTR [eax+4], 0x4` from clang's spill-init).
- `mov r16, imm16` (66 B8+rw), `mov r/m16, imm16` (66 C7 /0 iw). Still not seen in practice — both pipelines either go through 32-bit moves or use byte stores. Add the same way (gap + pinned test) if they ever fire.
- `ret imm16` (C2 iw) — the stdcall caller-pop variant. movfuscator is cdecl; callers pop their own args.

Not in scope (yet): `PT_INTERP` / `PT_DYNAMIC` (dynamically-linked ELFs); FPU; `cmp` / `jcc` / EFLAGS for the guest's own control-flow (movfuscator only avoids them via the master_loop dispatch trick, which we model). cmp/jcc/EFLAGS *was* the gating issue for `printf` until the host-wrapper ABI made the in-guest strlen unnecessary — see "Library-stub generality (resolved)" below.

## Real movfuscator binary: where we got (and where the follow-up picks up)

Empirical scope check via `nm -u movfuscator-wasm/tests/goldens-o/return42.o` (the .o file is committed; no build required):

- 40 undefined symbols, **all of them movfuscator runtime**: `alu_eq`, `alu_x`, `alu_y`, `and`, `b0..b3`, `branch_temp`, `D0..D2`, `data_p`, `F0..F2`, `fp`, `jmp_d0..d2`, `jmp_f0..f2`, `jmp_r0..r3`, `on`, `pop`, `push`, `R0..R3`, `sel_data`, `sel_on`, `sel_target`, `sp`, `stack_temp`, `target`.
- **Zero libc references.** `hello.o` adds exactly `printf` and nothing else — i.e. libc only enters the picture for programs that actually call into it.

### What landed in this PR

- **Decoder is real-movfuscator-output complete** for everything that appears in the goldens. The `decoder_covers_return42_o_text` integration test in `cli/tests/e2e.rs` walks every byte of the committed `return42.o`'s `.text` through `decode()` and asserts no `UnknownOpcode`. Adding new instructions until this passed surfaced `moffs` MOV forms (`A0`/`A1`/`A2`/`A3` + their 66-prefixed siblings), `mov sreg, r/m16` (`8E /r`), and the indirect-memory `jmp r/m32` (`FF /4`).
- **Loader produces a Linux-style startup image.** `flatten_with_stack` writes `argc=0, argv=NULL, envp=NULL, auxv=NULL` at the top of the stack region and points `%esp` at `argc`. Without this, the first thing real crt0 does (`mov esp, [esp+0]`) faulted at the top-of-region boundary.
- **`mov cs, ax` is modelled as a stand-in for the SIGSEGV-trampoline dispatch trick** (`Insn::MovfuscatorDispatchJump`): the placeholder semantic is "jump to the full 32-bit value of the source register's parent". This is **wrong in the general case** — see the next-PR section.
- **Env-var-gated instruction trace.** Set `MOVIE86_TRACE=1` to dump `eip eax ebx ecx edx esp` before each `step`. Cheap (only branch in the loop), invaluable for debugging where a real binary diverges.
- **Debugger CLI flags.** `movie86 --trace --break-at HEX --max-steps N --watch HEX <elf>` gives focused debug tooling for the bring-up work: trace, address breakpoint, instruction-count limit, and memory watchpoints (sampled per step, so any write — `mov`, syscall, self-modifying-code — is reported). The exposed `run_elf_with_debug(bytes, host, DebugConfig)` lets tests use the same machinery.

### Where the follow-up picks up

A static link of `return42.o` + `crt0_cf.o` + `crtf_cf.o` + `crtd_cf.o` + `softfloat32.o` + a tiny `stubs.s` (`sigaction` returns 0, `exit` issues `int 0x80` syscall 1) produces a runnable ELF that movie86 now loads, executes hundreds of instructions in, then hits the `mov cs, ax` dispatch at `0x8049d6e` and jumps to `0x08486118` (= `&on`, a data symbol) — which decodes as `UnknownOpcode(0)`.

The root cause is in `movfuscator.c:877-887` and `:2810-2840`:

- `crt0` calls `sigaction(SIGSEGV, sa_dispatch, 0)` to install `dispatch` as the SIGSEGV handler. Same for SIGILL with `master_loop`.
- `dispatch` (in `.plt`, generated by movfuscator) is `mov esp, [sp]; jmp [external]` — i.e. when SIGSEGV fires it transfers to whatever address has been stored at `external`.
- `external` is a function pointer the runtime *self-modifies* before each dispatch.

So "what `mov cs, ax` does" depends on which handler was registered via `sigaction`. With our no-op stub, no handler was registered, so the placeholder "jump to EAX" semantic is a wrong guess.

**What landed in this PR for the dispatch path:**

- **ELF symbol-table parsing** (`elf::parse_symbols`) — exposes `(name, st_value)` pairs from `.symtab`/`.strtab` via `LoadedElf::find_symbol`.
- **Signal-handler tracking on `Cpu`** — `Cpu::set_signal_handler(Signal, addr)`; with no handler registered the dispatch traps with `Fault::SignalHandlerUnregistered`.
- **CLI wires it up automatically** — `run_elf_with_host` looks up `dispatch` (→ SIGSEGV) and `master_loop` (→ SIGILL) at load time and registers them. `mov cs, ax` now correctly jumps into `dispatch`.

`dispatch` itself is `mov esp, [sp]; jmp [external]`. It runs end-to-end in movie86 but jumps to `mem[external]` which is `0` at process start — the runtime is supposed to self-modify `external` to the resume-target before each dispatch, and that's the part the follow-up needs.

**Open question for the next PR:** what's the exact mechanism by which `external` gets the right value?

**Solved via smart-friend + movfuscator.c source reading:**

- `mov cs, ax` (opcode `8e c8`) is movfuscator's deliberate **SIGILL** trigger — emitted by `progend()` (movfuscator.c:3091) under the `mov_loop` branch. It is *not* a SIGSEGV trigger.
- The runtime registers `SIGILL → master_loop` via `sigaction` (movfuscator.c:2832). So `mov cs, ax` re-enters `master_loop` for the next iteration.
- The other dispatch — `SIGSEGV → dispatch` — is for **external libc calls**. movfuscator emits `movl $callee, (external)` followed by a deliberate NULL deref at each external call site (`jmp_extern()` in movfuscator.c:2397). The NULL deref faults; the handler `dispatch` does `mov esp, [sp]; jmp [external]` to call the libc function.
- `return42` makes no external calls, so `external` is correctly never written. It additionally has a **direct `jmp exit` at `0x08049287`** (inside master_loop's body) — that's the intended termination path, not the dispatch trick.

`Insn::MovfuscatorDispatchJump` is now wired to the SIGILL handler instead of SIGSEGV. With that fix the emulator runs the binary for 50M+ steps without crashing — but it never reaches `jmp exit`.

### Next puzzle (where the bring-up was once stuck)

The emulator was stuck in a **deterministic infinite loop** inside `master_loop` (605 unique EIPs visited per iteration; ~600 instructions per iteration). Diagnosed via `--watch`:

- `toggle_execution` (`0x848611c`) starts at 1, is set to 0 in iteration 1 at `0x0804909f` (`mov [0x848611c], 0x0`), and **never returns to 1**.
- master_loop's prologue uses `toggle_execution` as the index into `sel_on[]`. With `toggle_execution = 1`, `sel_on[1] = &on`, so writes to that slot land on `on`. With `toggle_execution = 0`, `sel_on[0]` points at a *discard area* in BSS (`0x086866d0`), so the writes have no effect — every iteration after the first is a no-op.

So the missing piece was whatever's supposed to flip `toggle_execution` back to 1 between iterations. The **only** write to `toggle_execution` is the `→ 0` at `0x0804909f`. There is no `→ 1` write. The flip must happen via an indirect store, and we hadn't found which `mov [reg], val` site had `reg == &toggle_execution`.

Three candidate explanations explored and three ruled out:

1. ~~Indirect store via `mov [data_p], val` with `data_p == &toggle_execution`~~ — *ruled out*: `grep` of the linked binary shows the value `0x848611c` (= `&toggle_execution`) appears in zero data slots and only at the two direct-reference instructions (`mov eax, ds:0x848611c` at 0x804908d and the `→ 0` write at 0x804909f). No indirect path can ever target this slot.
2. ~~Signal-handler-return restores saved state~~ — *ruled out*: master_loop never reads `[esp+...]` (the signal-frame layout). It runs on the movfuscator shadow stack via `mov esp, [sp]`, completely independent of the signal-stack context.
3. ~~Decoder bug in `crt0_cf` / `crtf_cf`~~ — *ruled out*: the `investigate_decoder_coverage` test (`#[ignore]`, env-var-driven; `MOVIE86_FIXTURE=path cargo test -- --ignored investigate_decoder_coverage`) walks both `.text`s through `decode()` cleanly. crt0_cf is 115 instructions, crtf_cf is 2.

### Real next puzzle — solved

The whole investigation above was operating on the **wrong CRT**. smart-friend tracked it down by reading `movfuscator.c` and confirming with `readelf -r` on `crt0_cf.o` vs `crt0.o`:

- `crt0_cf.o` / `crtf_cf.o` / `crtd_cf.o` are the **control-flow CRT** (`--no-mov-flow` build). They use native `e9 jmp main` / `e9 jmp exit` in master_loop. That's the design — those direct jumps come from real R_386_PC32 relocations in the `_cf` objects.
- `crt0.o` / `crtf.o` / `crtd.o` are the **mov-loop CRT** (the actual mov-only build movfuscator-wasm uses). master_loop has no native `jmp main` / `jmp exit` — it routes via `target` / `branch_temp` and the SIGSEGV / SIGILL dispatch tricks.

The static-link attempt used `_cf` objects, which is why master_loop appeared to "always direct-jump back to main with no escape" — that was the intended `_cf` shape, not a bug.

### Final wiring (what got us to end-to-end)

Switched to the mov-loop CRT (`crt0.o` + `crtf.o` + `crtd.o` + `softfloat32.o` + `stubs.o`) and re-ran. With the wiring:

- `mov cs, ax` → `Insn::MovfuscatorDispatchJump` → SIGILL handler (`master_loop`)
- **Unmapped-on-read** → SIGSEGV handler (`dispatch`) — this is movfuscator's `mov (%eax), %eax` with `eax=0` NULL-deref trigger, used to call libc functions including `exit`.
- ELF symbol-table lookup of `dispatch` / `master_loop` → handler registration.

…the binary runs end-to-end through movie86: 1019 steps through crt0 startup → master_loop dispatch → main body → return → master_loop → `external = &exit` → NULL deref → SIGSEGV → dispatch → `jmp [external]` → my `exit` stub → `int 0x80` syscall 1 → process termination.

**`movie86 /tmp/movie86-link/return42-real.elf` exits cleanly.** Real movfuscator-built mov-only binary now runs.

### Real movfuscator binaries: end-to-end demos

There are now **two** ways to bridge libc calls into movie86:

- **cdecl stubs.** A fixture-specific assembly stub for each libc fn,
  ending in a real `int 0x80` syscall (e.g. `printf` → `write(1, …)`).
  Stubs hardcode their own behavior (the `hello` stub hardcodes a
  6-byte write because mov-only `strlen` needs `cmp + jcc` + EFLAGS).
  Doesn't scale, but the binary still runs on real hardware.

- **Host-wrapper stubs** (current preferred path). Every wrapped fn is a
  uniform `int $0x81; ret` sentinel. movie86 traps on int 0x81, the
  host-side [`LibcHost`](core/src/libc_host.rs) reads cdecl args from
  `[esp+4..]` and does the work — `printf`'s format parser lives in
  Rust, no in-guest `strlen` needed. Designed for wasm portability:
  the same trait will plug a wasm host in later.

  `StdHost::scan_libc_stubs` walks the ELF symbol table at load time
  and registers any sentinel it finds (looks for `CD 81` at &exit /
  &sigaction / &printf), so both link styles coexist in the same
  movie86 binary — no flag needed.

| Program | Linker script | Behavior through movie86 | Notes |
|---|---|---|---|
| `return42.c` | `link-real-return42.sh` | exits with status **0** | cdecl `int 0x80` exit stub. crt0 hardcodes `push("$0"); jmp_extern("exit")` — main's return value is **ignored**. Confirmed against the native build too. |
| `hello.c` | `link-real-hello.sh` | prints `Hello`, exits 0 | cdecl stub with **hardcoded 6-byte** `write` (= `"Hello\n"`). Sufficient for the committed fixture; doesn't generalize. |
| `hello.c` | `link-real-hello-host.sh` | prints `Hello`, exits 0 | **Host-wrapper** stub. printf goes through `LibcHost::libc_call` → Rust's format parser. No 6-byte hardcode; would handle `%s`/`%d`/`%c` for any longer format too. |

All demos exercise the same end-to-end path through master_loop:

```
crt0 → master_loop → main (mov-only body) → return → master_loop's
  exit-call block → push retaddr + args on shadow stack →
  set external = &callee → NULL deref → SIGSEGV →
  Cpu::step routes Unmapped(0) → SIGSEGV handler →
  dispatch (mov esp, [sp]; jmp [external]) → libc stub
```

Only the last hop differs: the cdecl stub ends in `int 0x80`; the
host-wrapper stub ends in `int $0x81; ret`.

### How to reproduce

```sh
# Materialize the gitignored runtime objects (5–15 min):
cd ../movfuscator-wasm && make setup && make build-native && cd -

# return42 demo (cdecl exit stub):
movie86/scripts/link-real-return42.sh
cargo run --release --bin movie86 -- /tmp/movie86-link/return42-real.elf
echo $?    # → 0  (movfuscator quirk — see table)

# hello demo (cdecl printf stub, hardcoded length):
movie86/scripts/link-real-hello.sh
cargo run --release --bin movie86 -- /tmp/movie86-link/hello-real.elf
# prints: Hello — echo $? = 0

# hello demo (host-wrapper printf, no hardcoded length):
movie86/scripts/link-real-hello-host.sh
cargo run --release --bin movie86 -- /tmp/movie86-link/hello-host.elf
# prints: Hello — echo $? = 0  (same output, but through the wrapper)
```

## 2026-05-28 follow-up: why `jmp main` exists

The key finding is that the puzzling `0x0804922e: e9 ... jmp main` in our
static fixture is **not** a mov-only path that failed to self-modify at
runtime. It comes from linking against the **wrong CRT family**.

- The static ELF we were debugging (`/tmp/movie86-link/return42.elf`) was
  linked with `crt0_cf.o/crtf_cf.o/crtd_cf.o`.
- `crt0_cf.o` really does contain direct branch relocations:
  - at `.text+0x223`: `R_386_PC32 main`
  - at `.text+0x27c`: `R_386_PC32 exit`
- After link those become the exact bytes we observed in the fixture:
  - `0x0804922e: e9 59 00 00 00    jmp 0x0804928c <main>`
  - `0x08049287: e9 ...            jmp exit`

So hypothesis `X` is false in its original form: the `e9` bytes are not
"supposed to turn into movs later". They were emitted that way by
`crt0_cf.o` at link time.

The decisive comparison is with the non-`_cf` CRT:

- `vendor/movfuscator/build/crt0.o` does **not** have a `R_386_PC32 main`
  relocation there.
- Instead, at `.text+0x223` it has `R_386_32 main`, immediately followed by
  stores through `branch_temp` and `sel_target`, then a spill of the jmp
  register bank.
- In the linked dynamic ELF (`/tmp/inst-check/return42.elf`), that becomes:
  - `0x0804920e: mov eax, 0x88049339`
  - `0x08049215: mov [stack_temp], eax`
  - `0x0804925e: mov eax, 0x880495ba`
  - `0x08049263: mov [branch_temp], eax`
  - `0x08049268..0x08049333`: store target + jmp regs via `sel_target` /
    `sel_data`
- There is **no direct `jmp main`** in that dynamic binary's `master_loop`.

This matches movfuscator's source generator:

- `movfuscator.c:3094`:
  - when `mov_loop` is enabled, the runtime ends with `movw %ax, %cs`
    (the SIGILL re-entry trick)
  - otherwise it emits `jmp master_loop`
- `crt0_cf.o` is the non-`mov_loop` control-flow CRT.
- `crt0.o` is the mov-loop CRT that uses `target`/`branch_temp` state instead
  of direct branches.

### Signal-handler hypothesis

Hypothesis `Y` also looks false.

- `movfuscator.c:876-889` emits `sa_dispatch` / `sa_loop` as plain `struct
  sigaction` objects with `.sa_handler = dispatch/master_loop`.
- `movfuscator.c:2817-2835` just installs them with `sigaction(SIGSEGV, ...)`
  and `sigaction(SIGILL, ...)`.
- There is no generated code here that rewrites a saved `ucontext_t` / signal
  frame to redirect `EIP`.

So the rich "handler mutates saved EIP on signal return" model does not appear
to be what this runtime is doing.

### What this means for movie86

The emulator bug hunt was being driven by a fixture mismatch:

- Our static bring-up fixture used `*_cf.o`, which intentionally contains
  native direct jumps in `master_loop`.
- `movfuscator-wasm`'s `test-ld` / production link flow uses `crt0.o/crtf.o/crtd.o`,
  whose `master_loop` is mov-only in the relevant sense and routes control by
  writing `target` / `branch_temp`.

So the "master_loop always direct-jumps back to main, therefore movfuscator's
design is inconsistent" conclusion was an artifact of linking the wrong CRT.

## 2026-05-28 follow-up: other fixtures tried

After the return42/hello demos landed, the remaining fixtures
(`return0`, `sum10`, `branch`, `multi-add`) were linked against the same
mov-loop CRT (`crt0.o/crtf.o/crtd.o`) + the minimal `sigaction`/`exit`
cdecl stub from `link-real-return42.sh` (no `printf` needed since none
print).

| Program | Steps to exit | Status |
|---|---|---|
| `return0.c` | ~1k | exits 0 ✓ |
| `sum10.c` | <1M | exits 0 ✓ (return value invisible — crt0 hardcodes exit 0) |
| `branch.c` | <1M | exits 0 ✓ (same) |
| `multi-add.c` | >5×10⁸ | **does not terminate within 500M steps** |

`multi-add.c` calls `add(20, 22)` — a real C-level function call. Tracing
the master_loop shows only **1474 unique PCs** visited across 1M steps,
and that same set of PCs across 100M steps. movfuscator's master_loop
executes a fixed mov-only instruction sequence each iteration; logical
progress is encoded in *memory state*, not in different code paths. So
PC-cycling alone cannot distinguish "stuck" from "extremely slow" —
each C-level statement may need many master_loop iterations once the
function-call machinery (shadow-stack push, target dispatch via
`branch_temp`, callee prologue/epilogue) is exercised.

For now: documented as a known-slow fixture; not a movie86 bug we can
point to without disassembling master_loop and tracing the
`target`/`sel_target`/`branch_temp` memory cells through the call.
Function-call throughput would be a natural focus for a perf pass once
movie86 has more native-code coverage (current 1474-PC body suggests
each iteration is dominated by movfuscator's dispatch overhead, which
movie86 emulates one mov at a time).

**Update (snapshot+diff)**: the new `--snapshot-at-step / movie86 diff`
infra (see § "Snapshot / diff" below) confirms multi-add IS making
memory-state progress, just at an extremely sparse rate:

- step 1k → step 100k (99k-step window): 43 bytes changed across 5 pages
- step 100k → step 10M (9.9M-step window): 19 bytes changed across 3 pages

So it's not literally stuck, but ~2 changed bytes per million steps is
not going anywhere reasonable in human time. The repeat structural
locations (`0x08286xxx`, `0x08487xxx`, `0x08687xxx`) likely point at
the dispatch / target / branch_temp state cells movfuscator's
master_loop walks per logical C-level operation — confirming the
"logical progress encoded in memory state, not PC" hypothesis. Whether
the early concentration of changes is "initialization" vs the steady-
state being "near-deadlock" needs another investigation pass.

`sum10` and `branch` have no observable side effects through movie86
because both rely on `main`'s return value, which the crt0 always
overrides with `exit(0)`. That is a movfuscator convention, not a
movie86 limitation, and is the same reason `return42` exits 0.

**Update (2026-05-28 deep dive)**: `--log-writes-in` lets us trace
the dispatch chain. `multi-add` is genuinely deadlocked at the
dispatch-flag level:

- `on` (0x08487118) flips to 1 twice (steps 25, 350), to 0 twice
  (steps 142, 1154), then **stuck at 0 forever**.
- `b0` (0x08286fa0) — the `alu_eq` result that re-arms `on` via
  `execution_on(b0)` — flips to 1 at step 268, 0 at step 579, then
  **stuck at 0**.
- `target` (0x08487128) only ever holds `0x8804958a` (= `&main`
  encoded, set at step 106) and `0x08049c14` (the post-call
  continuation, set at step 1118 via the `alu_add16` table chain
  `0x88049c14 + 0x80000000 mod 2^32`).
- `branch_temp` (0x082870c0) then oscillates 0x14 ↔ 0x8804958a
  forever (period ~710 steps).

**Crucially**: linking `multi-add` with real libc and running it
natively on i386 (`/usr/bin/ld ... -dynamic-linker /lib/ld-linux.so.2
-lc -lm ...`, then exec) **also fails to terminate within 10 minutes
of CPU time** (`user 1:10, sys 3:39` in 10:00 wall).

**Update (2026-05-29 root cause)**: an earlier draft framed this as
"movfuscator is just slow on function calls". That was wrong. A clean
A/B test pinned the real bug:

| Form | Native i386 | movie86 |
|---|---|---|
| `inline-add` — single .c with `add` inlined alongside `main` | **0.02s ✓** | **0.21s ✓** |
| `multi-add` — same C content, split into `multi-add.c` (main) + `multi-add-helper.c` (add), linked together | **>10 min ✗** | **>5×10⁸ steps ✗** |

Single-`.c` programs with calls / recursion work fine in both
environments (`upstream-hanoi` 27s, `upstream-nqueens` 0.9s,
`upstream-hello` 13ms, all native). **Only 2-`.o` linkage breaks.**

The bug is in movfuscator's **call classification at compile time**
(smart-friend GPT-5.5 traced this to `movfuscator.c`'s CALL emission
checking `s->sclass == EXTERN`):

- When compiling `multi-add.c`, the symbol `add` is unresolved (defined
  in a different translation unit) → movfuscator emits the **external
  call path** (`jmp_extern`, the SIGSEGV-trampoline / libc-style
  dispatch that writes an *un-obfuscated* address to `external`).
- When `multi-add-helper.c` is compiled separately, `add` is emitted
  as a **normal movfuscated function**, whose prologue gates execution
  on `target == 0x8804a298` — the **obfuscated** label form (= real
  address `+ 0x80000000`, per `MOV_OFFSET`).
- After link the caller uses the external protocol but the callee
  expects the internal one. The compares never match → `b0` / `on`
  never re-arm → permanent dispatch deadlock.

Verified in `multi-add-real.elf`:

```asm
8049bfc: mov DWORD PTR ds:0x8687194, 0x804a298   ; external = &add
                                                  ; (un-obfuscated, jmp_extern)
0804a298 <add>:
804a29d: mov edx, 0x8804a298                      ; expected target value
                                                  ; (obfuscated, internal compare)
```

The byte-identical link test in `movfuscator-wasm/tests/run-multi.mjs`
only verifies that `wasm-ld` produces the same bytes as host
`/usr/bin/ld` — it never **runs** the linked binary, so this deadlock
has been latent there as well.

**Workaround**: amalgamate sources into a single `.c` (e.g.
`#include "multi-add-helper.c"`). movfuscator has no `--whole-program`
flag — separately compiled `.o` files don't compose safely when one
movfuscated function calls another.

**Verdict for movie86**: nothing to fix. The `--log-writes-in` tool
built during the investigation is now permanent infra. multi-add is
left in the demos table as a **known-broken movfuscator-side fixture**
with the workaround documented.

## Library-stub generality (resolved → host-wrapper ABI)

The original hello demo's `printf` stub hardcoded a 6-byte write
because real `strlen` needs `cmp + jcc` + EFLAGS, which movie86
doesn't implement. The fix could have been "add cmp/jcc/EFLAGS" — a
multi-week milestone — but the cheaper and more wasm-friendly answer
was to **move the libc body out of the guest**:

- Every wrapped fn is a uniform sentinel stub `int $0x81; ret` (3
  bytes).
- movie86 dispatches `int 0x81` to the host's [`LibcHost`] trait,
  which reads cdecl args from `[esp+4..]` and does the work in Rust.
- `printf`'s format parser lives on the host — bounded fmt scan
  (`PRINTF_MAX_LEN = 4096`), `%s`/`%d`/`%c`/`%%` only, `%n` rejected
  (returns -1 + flushes partial output).
- `StdHost::scan_libc_stubs` auto-detects sentinel stubs by walking
  the ELF symbol table at load time, so the host code never has to
  hand-register addresses.
- Designed for the planned wasm runtime: the wasm host plugs in the
  same `LibcHost` trait, the cdecl ABI is unchanged.

The previous cdecl `int 0x80` stubs (e.g. `link-real-hello.sh`) still
work — both link styles coexist, scan_libc_stubs only fires when it
sees the `CD 81` sentinel byte pattern.

`cmp`/`jcc`/EFLAGS remain on the roadmap for the guest's own
control-flow needs (movfuscator only avoids them via the master_loop
trick; a future mov-only LLVM backend may want them honestly), but
they are no longer load-bearing for libc-using fixtures.

## GDB attach (`--gdb-listen ADDR`)

`cli/src/gdb_target.rs`. movie86 speaks the gdb Remote Serial Protocol
(RSP) so the user can attach gdb and drive interactively — registers,
memory, `c` / `s` / `b *0x...` / Ctrl-C — instead of inventing one-off
`--watch` flags every time.

Built on the [`gdbstub`](https://crates.io/crates/gdbstub) crate (cli
only — the `movie86` library crate stays dep-free + no_std). Rolling
our own RSP would be much more than the obvious 400 LOC once you
handle ACK / partial reads / Ctrl-C / `target.xml` / GDB quirks
(smart-friend's review).

**Design decisions:**

- **Separate `run_elf_with_gdb` entry.** Gdb owns the run/stop state
  machine — folding it into the existing tight `loop { cpu.step() }`
  in `run_elf_with_debug` would couple transport to execution.
  Bootstrap (ELF load, esp, signal handlers, libc-stub scan) is the
  only thing shared.

- **i386 target description**: we ship `gdbstub_arch::x86::X86_SSE`
  so the user doesn't need `set arch i386` — `target remote :1234`
  is enough.

- **EFLAGS = 0**. movie86 has no flags register today. Returning 0
  keeps the register-file shape stable for gdb; writes via
  `set $eflags = X` are silently dropped (unmodeled).

- **Breakpoints**: stub-side tracking, **not** int3 byte-rewrites.
  Behaves as "execution breakpoint at this eip" — fine for movie86
  since we don't decode `int3`. The breakpoint set lives on
  `GdbTarget` and is checked before each step in `ExecMode::Continue`.

- **Fault → signal mapping:**

  | Fault | gdb signal |
  |---|---|
  | `Unmapped` | `SIGSEGV` |
  | `UnknownOpcode` / `UnsupportedInterrupt` / `DecodeTruncated` | `SIGILL` |
  | `UnimplementedMov` / `UnknownSyscall` | `SIGSYS` |
  | `SignalHandlerUnregistered` | `SIGTRAP` |
  | `Exit(n)` | gdb `W` packet with `n & 0xff` |

- **`c` is interruptible.** `wait_for_stop_reason` checks `conn.peek()`
  between steps so Ctrl-C from gdb arrives within one instruction —
  no blind tight-loop.

**Usage:**

```sh
# Terminal 1:
movie86 --gdb-listen 127.0.0.1:1234 prog.elf
# movie86: waiting for gdb on 127.0.0.1:1234

# Terminal 2:
gdb -ex 'target remote :1234' -ex 'set arch i386'
(gdb) info registers
(gdb) x/5i $eip
(gdb) b *0x08049092
(gdb) c
```

## Memory-write log (`--log-writes-in START:END`)

`cli/src/logging_memory.rs`. Per-write tracer for a caller-supplied
address range. Answers the question snapshot+diff *couldn't*: "which
instruction wrote to this dispatch cell, in what temporal order?".

Built as a memory adapter (smart-friend's option B), not a trait
change: `LoggingMemory<M: Memory>` wraps any `Memory` impl, intercepts
writes, and captures `(addr, width, old, new)` into a per-step pending
buffer. The run loop drains the buffer after each `cpu.step()` and
prepends `(step_count, eip)`.

- **Range matching is inclusive-start, exclusive-end** (`START..END`,
  Rust's `..` convention).
- **Empty `log_ranges` ⇒ zero-cost pass-through** — one `is_empty`
  check per write, no allocations.
- **`write_bytes` (loader) explodes into per-byte entries** in-range —
  rare in practice (the adapter sits on top of an already-loaded
  memory) but kept correct for completeness.
- **Multiple ranges** via repeating `--log-writes-in`.

Applied to `multi-add` against the 3 pages the snapshot diff revealed
(0x08286xxx / 0x08487xxx / 0x08687xxx), the log immediately surfaced
movfuscator's function-call dispatch machinery:

```
[     0] write u32@0x08487100: 0x00000000 -> 0x088976d0  (eip=0x08049012)
[    25] write u32@0x08487118: 0x00000000 -> 0x00000001  (eip=0x0804909f)
[    26] write u32@0x0848711c: 0x00000001 -> 0x00000000  (eip=0x080490a9)
[    33] write u32@0x08286fc0: 0x00000000 -> 0x00000000  (eip=0x080490d2)
...
[   102] write u32@0x082870c0: 0x00000000 -> 0x8804958a  (eip=0x08049238)
[   108] write u32@0x08487134: 0x08687134 -> 0x08687150  (eip=0x0804925c)
[   118] write u32@0x08487134: 0x08687150 -> 0x08687160  (eip=0x08049290)
[   126] write u32@0x08487134: 0x08687160 -> 0x0868716c  (eip=0x080492bb)
```

`0x8804958a` is `&add` (the callee), `0x08487134` is movfuscator's
`sel_target` slot ping-ponging through stack frames as the shadow
stack pushes — exactly the dispatch dance multi-add is slow on. With
this tool the per-iteration cost is visible, not hidden.

## Snapshot / diff

`cli/src/snapshot.rs` + `cli/src/diff.rs`. Memory + register state
capture and comparison — the answer to "is the multi-add fixture
making progress, or is it stuck?".

**Snapshot file format** (custom binary, not gdb core / QEMU):

```
  0..4    magic = b"M86S"
  4..6    version u16 LE
  6..7    kind u8 (AfterStep/Exit/Fault/Break/MaxSteps)
  8..16   step_count u64 LE
 16..48   regs[8] u32 LE
 48..52   eip u32 LE
 52..56   sigsegv_handler (or u32::MAX = None)
 56..60   sigill_handler
 60..64   detail (kind-specific u32)
 64..68   mem_base
 68..72   mem_len
 72..     raw memory bytes
```

**Capture semantics is "AFTER step N succeeded"** — `step_count` is
the count of `Cpu::step()` calls that returned `Ok`. For fault
captures, `step_count` is the count before the faulting step; `eip`
still points at the faulting instruction.

**CLI:**

```sh
# Capture at step N, also capture whenever the run halts:
movie86 --snapshot-at-step 1000 a.snap --snapshot-on-stop b.snap prog.elf

# Compare two snapshots:
movie86 diff a.snap b.snap
```

Diff output (span-based to handle a 10 MB `FlatMemory`):

- Register deltas (only changed registers listed)
- Step delta + stop kind for each snapshot
- Signal-handler deltas
- Memory deltas as coalesced ranges (gap ≤ 16 bytes), capped at 32
  ranges; rest summarized
- 4 KiB page summary so structural location is visible at a glance
  (stack / data / heap)

Designed for the wasm runtime: snapshot uses the `Memory` trait, not
`FlatMemory` directly, so a future paged memory impl works too.
