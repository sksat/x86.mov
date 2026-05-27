# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this directory.

`movie86` is a Rust `no_std` emulator for mov-heavy ELF32 i386 binaries — the output of [movfuscator-wasm](../movfuscator-wasm/) and the planned mov-only [LLVM backend](../llvm-mov/) (when it lands). The name is mov + ie: watching a mov-only binary execute is the joke.

## Layout

Two-crate Cargo workspace at this directory.

- [`core/`](core/) — `movie86-core`, `no_std` + `alloc`. Library only. Decoder, CPU, memory abstraction, syscall trait, ELF loader. This is the artifact that will eventually build to `wasm32-unknown-unknown` and run in a browser.
- [`cli/`](cli/) — `movie86-cli`, `std`. Provides `lib.rs` (the `run_elf` entry point + `StdHost` that wires Linux i386 syscalls to the surrounding process) **and** a thin `bin` target at [`cli/src/main.rs`](cli/src/main.rs). The library half exists specifically so end-to-end tests in [`cli/tests/`](cli/tests/) can drive the same code path the binary uses without spawning a subprocess.

Run the bin with `cargo run -p movie86-cli -- path/to/file.elf`; exit status is the guest's `exit(2)` status, low 8 bits, with `1` for any fault.

## Architectural decisions (don't undo without reading the why)

- **Decoder and execution are separate.** [`decode::decode(&[u8]) -> Result<(Insn, u8), Fault>`](core/src/decode.rs) is a pure function over bytes. [`Cpu::step()`](core/src/cpu.rs) calls it. Same decoder will host a future disassembler / tracer / coverage tool; fusing it into `step` would make those reuse cases hard.

- **Memory is a trait, not a flat `Vec<u8>`.** [`Memory`](core/src/mem.rs) abstracts the guest address space; the first impl ([`FlatMemory`](core/src/mem.rs)) is a single contiguous region. Multi-region / paged variants can slot in without changing the loader or CPU. `FlatMemory::new_zeroed` **rejects regions whose end runs past `0xffff_ffff`** at construction — the guest space is `u32`, so a region past the top would let later accesses silently wrap.

- **Syscalls trap unless the host knows them.** The [`SysHost`](core/src/syscall.rs) trait is the only way `int 0x80` does anything useful. There is intentionally **no default no-op handler** — silent success on unknown syscall numbers hides bugs. Tests use either `PanicHost` (asserts no syscall happens) or a `RecordingHost` (captures the args).

- **`step()` returns the next `eip` from `execute`.** Most instructions return `next_eip_default` (eip + insn-len); `jmp rel32` returns `next_eip_default + disp` — i.e. relative to the *end* of the jmp, per Intel SDM. Don't add a length to eip in `step` after `execute` returns: that's already baked into the default.

- **Operand width is encoded in the operand variant.** [`Operand::Reg32(_)` / `Mem32(_)` / ...](core/src/insn.rs) is the typed way of saying "32-bit operand" — `Mov { dst: Reg8(_), src: Mem32(_) }` is unrepresentable. The decoder is responsible for emitting matching widths; mismatched widths trap as `UnimplementedMov`.

## TDD style

- New instructions: unit decoder test (byte sequence → expected `Insn`), executor test (run a 1-insn program, assert register/memory effects), and where useful a property test (proptest dev-dep). PBT is especially valuable for catching encoding/semantic asymmetries — for `mov r32, r32` we have a property over all 64 (dst, src) pairs.
- Adding a `Fault` variant: prefer trapping early with a distinct variant over reusing an existing one. `Unmapped(eip)` from `fetch` and `DecodeTruncated` from `decode` were merged in an early version and codex's review caught it — they hide different real bugs.
- 8-/16-bit register aliasing semantics (`AH`/`AL` over `EAX`) is the easiest place to introduce a subtle bug. Tests pin the aliasing explicitly: writing `AH` should leave bits 7:0 alone; writing `AL` should leave bits 31:8 alone.

## Things future Claude shouldn't relearn

- **The address-space rejection is at `FlatMemory::new_zeroed`, not at access time.** Construction-time rejection keeps the access path simple. If you find yourself wanting to allow regions past `0xffff_ffff`, you've probably written a bug.
- **`Reg32::Esp == 4` collides with the SIB-byte sentinel** when `r/m == 4` under `mod != 11` — that's why the decoder routes through `parse_sib_address` before treating `r/m` as a register. Likewise `r/m == 5` under `mod == 00` means "disp32, no base" (not EBP); under `mod == 01/10` it's EBP + disp. The Intel SDM Vol. 2A Table 2-3 sentinels are easy to forget.
- **The CLI's `StdHost` only knows `exit(1)` and `write(4)`.** Adding a syscall means adding an arm to `StdHost::syscall` and (probably) a regression test in `cli/tests/e2e.rs`. Don't silently extend the syscall set in `core` — the host trait is the seam.
- **`vec![0; N]` not `Vec::new(); resize(N, 0)`** — clippy's `slow_vector_initialization` catches the difference. Comes up in test helpers that build ELF bytes.

## Scope (and what's NOT in scope)

In scope: the instructions movfuscator + the planned mov-only LLVM backend actually emit. That's mov-heavy (all `mov` widths, ModR/M, SIB, the 0x66 operand-size prefix), plus `jmp rel32` (E9), `int 0x80` (CD 80), `push`/`pop` (50+rd / 58+rd), and `call rel32` / `ret near` (E8 / C3). Linux i386 syscalls: at minimum `exit(1)` and `write(4)`.

**Deliberately not implemented even though they're valid x86:**

- `mov r8, imm8` (B0+rb), `mov r/m8, imm8` (C6 /0), `mov r16, imm16` (66 B8+rw), `mov r/m16, imm16` (66 C7 /0 iw). The movfuscator goldens contain **zero** `movb $imm, ...` and zero `movw $imm, ...` instructions — movfuscator clears registers with `mov r32, imm32` and then byte-loads from memory, so it never materializes a sub-32-bit immediate. Adding these encodings before the LLVM backend exists would be pure speculation. If `Fault::UnknownOpcode(0xB0..=0xB7 | 0xC6)` ever fires in practice, fill the gap then with a test pinned to the input that exposed it.
- `ret imm16` (C2 iw) — the stdcall caller-pop variant. movfuscator is cdecl; callers pop their own args.

Not in scope (yet): the rest of the crt0 surface that gets linked into a *real* movfuscator-produced ELF — `call sigaction`, segment-register mov (`mov cs, eax`), indirect `jmp DWORD PTR ds:0x0`, FPU. End-to-end testing currently uses hand-crafted ELFs that skip crt0; running a real movfuscator-built binary is the explicit follow-up goal. The default link path in `movfuscator-wasm` is *dynamic* (`-dynamic-linker /lib/ld-linux.so.2 -lc -lm -lgcc`), so we also need a `PT_INTERP`/`PT_DYNAMIC`-supporting loader path before that goal is in reach — the current loader rejects them up front (`ElfError::DynamicLinkingUnsupported`).

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

### Next puzzle (where the bring-up is currently stuck)

The emulator is stuck in a **deterministic infinite loop** inside `master_loop` (605 unique EIPs visited per iteration; ~600 instructions per iteration). Diagnosed via `--watch`:

- `toggle_execution` (`0x848611c`) starts at 1, is set to 0 in iteration 1 at `0x0804909f` (`mov [0x848611c], 0x0`), and **never returns to 1**.
- master_loop's prologue uses `toggle_execution` as the index into `sel_on[]`. With `toggle_execution = 1`, `sel_on[1] = &on`, so writes to that slot land on `on`. With `toggle_execution = 0`, `sel_on[0]` points at a *discard area* in BSS (`0x086866d0`), so the writes have no effect — every iteration after the first is a no-op.

So the missing piece is whatever's supposed to flip `toggle_execution` back to 1 between iterations. We checked the binary; the **only** write to `toggle_execution` is the `→ 0` at `0x0804909f`. There is no `→ 1` write. The flip must happen via an indirect store, and we haven't found which `mov [reg], val` site has `reg == &toggle_execution`.

Three candidate explanations explored and three ruled out:

1. ~~Indirect store via `mov [data_p], val` with `data_p == &toggle_execution`~~ — *ruled out*: `grep` of the linked binary shows the value `0x848611c` (= `&toggle_execution`) appears in zero data slots and only at the two direct-reference instructions (`mov eax, ds:0x848611c` at 0x804908d and the `→ 0` write at 0x804909f). No indirect path can ever target this slot.
2. ~~Signal-handler-return restores saved state~~ — *ruled out*: master_loop never reads `[esp+...]` (the signal-frame layout). It runs on the movfuscator shadow stack via `mov esp, [sp]`, completely independent of the signal-stack context.
3. ~~Decoder bug in `crt0_cf` / `crtf_cf`~~ — *ruled out*: the `investigate_decoder_coverage` test (`#[ignore]`, env-var-driven; `MOVIE86_FIXTURE=path cargo test -- --ignored investigate_decoder_coverage`) walks both `.text`s through `decode()` cleanly. crt0_cf is 115 instructions, crtf_cf is 2.

### Real next puzzle — solved

The whole investigation above was operating on the **wrong CRT**. smart-friend tracked it down by reading `movfuscator.c` and confirming with `readelf -r` on `crt0_cf.o` vs `crt0.o`:

- `crt0_cf.o` / `crtf_cf.o` / `crtd_cf.o` are the **control-flow CRT** (`--no-mov-flow` build). They use native `e9 jmp main` / `e9 jmp exit` in master_loop. That's the design — those direct jumps come from real R_386_PC32 relocations in the `_cf` objects.
- `crt0.o` / `crtf.o` / `crtd.o` are the **mov-loop CRT** (the actual mov-only build movfuscator-wasm uses). master_loop has no native `jmp main` / `jmp exit` — it routes via `target` / `branch_temp` and the SIGSEGV / SIGILL dispatch tricks.

My static-link attempt used `_cf` objects, which is why master_loop appeared to "always direct-jump back to main with no escape" — that was the intended `_cf` shape, not a bug.

### What landed in this PR (final)

Switched to the mov-loop CRT (`crt0.o` + `crtf.o` + `crtd.o` + `softfloat32.o` + `stubs.o`) and re-ran. With the wiring:

- `mov cs, ax` → `Insn::MovfuscatorDispatchJump` → SIGILL handler (`master_loop`)
- **Unmapped-on-read** → SIGSEGV handler (`dispatch`) — this is movfuscator's `mov (%eax), %eax` with `eax=0` NULL-deref trigger, used to call libc functions including `exit`.
- ELF symbol-table lookup of `dispatch` / `master_loop` → handler registration.

…the binary runs end-to-end through movie86: 1019 steps through crt0 startup → master_loop dispatch → main body → return → master_loop → `external = &exit` → NULL deref → SIGSEGV → dispatch → `jmp [external]` → my `exit` stub → `int 0x80` syscall 1 → process termination.

**`movie86 /tmp/movie86-link/return42-real.elf` exits cleanly.** Real movfuscator-built mov-only binary now runs.

### Real movfuscator binaries: end-to-end demos

movfuscator's libc-call ABI is **cdecl**. `jmp_extern` pushes args then a return label and sets `esp = sp` so the callee sees the standard `[esp+0] = retaddr, [esp+4] = arg1` layout. The minimal stubs in [`scripts/link-real-return42.sh`](scripts/link-real-return42.sh) and [`scripts/link-real-hello.sh`](scripts/link-real-hello.sh) follow that convention.

| Program | Linker script | Behavior through movie86 | Notes |
|---|---|---|---|
| `return42.c` | `link-real-return42.sh` | exits with status **0** | movfuscator's crt0 hardcodes `push("$0"); jmp_extern("exit")` — it **ignores main's return value** and always exits 0. Confirmed against the dynamically-linked native build too. |
| `hello.c` | `link-real-hello.sh` | prints `Hello` to stdout, exits 0 | The `printf` stub hardcodes a 6-byte write (= length of `"Hello\n"`) because real `strlen` needs `cmp + jcc` + EFLAGS modeling, which is outside movie86's mov-only scope. Sufficient for the committed fixture; won't generalize. |

Both demos exercise the same end-to-end path:

```
crt0 → master_loop → main (mov-only body) → return → master_loop's
  exit-call block → push retaddr + args on shadow stack →
  set external = &callee → NULL deref → SIGSEGV →
  Cpu::step routes Unmapped(0) → SIGSEGV handler →
  dispatch (mov esp, [sp]; jmp [external]) → libc stub → int 0x80
```

### How to reproduce

```sh
# Materialize the gitignored runtime objects (5–15 min):
cd ../movfuscator-wasm && make setup && make build-native && cd -

# return42 demo:
movie86/scripts/link-real-return42.sh
cargo run --release --bin movie86 -- /tmp/movie86-link/return42-real.elf
echo $?    # → 0  (movfuscator quirk — see table)

# hello demo:
movie86/scripts/link-real-hello.sh
cargo run --release --bin movie86 -- /tmp/movie86-link/hello-real.elf
# prints: Hello
echo $?    # → 0
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

## Signal-handler hypothesis

Hypothesis `Y` also looks false.

- `movfuscator.c:876-889` emits `sa_dispatch` / `sa_loop` as plain `struct
  sigaction` objects with `.sa_handler = dispatch/master_loop`.
- `movfuscator.c:2817-2835` just installs them with `sigaction(SIGSEGV, ...)`
  and `sigaction(SIGILL, ...)`.
- There is no generated code here that rewrites a saved `ucontext_t` / signal
  frame to redirect `EIP`.

So the rich "handler mutates saved EIP on signal return" model does not appear
to be what this runtime is doing.

## What this means for movie86

The emulator bug hunt was being driven by a fixture mismatch:

- Our static bring-up fixture used `*_cf.o`, which intentionally contains
  native direct jumps in `master_loop`.
- `movfuscator-wasm`'s `test-ld` / production link flow uses `crt0.o/crtf.o/crtd.o`,
  whose `master_loop` is mov-only in the relevant sense and routes control by
  writing `target` / `branch_temp`.

So the "master_loop always direct-jumps back to main, therefore movfuscator's
design is inconsistent" conclusion was an artifact of linking the wrong CRT.

## Recommended fix

1. Stop using `crt0_cf.o/crtf_cf.o/crtd_cf.o` for the real-binary fixture.
2. Rebuild the fixture with `crt0.o/crtf.o/crtd.o` so it matches
   `movfuscator-wasm`'s `test-ld` output.
3. Re-run the emulator against that fixture before changing signal semantics
   again; the next real problem should be in mov-loop control-state handling,
   not in the presence of impossible direct `jmp main` bytes.

I could not complete the "native dynamic execution" check inside this sandbox:
invoking `/lib/ld-linux.so.2 /tmp/inst-check/return42.elf` terminates with
`Bad system call`, so the environment is blocking the guest rather than the
binary proving success/failure. The disassembly / relocation delta above is
still decisive for the original `jmp main` question.

## CI

`.github/workflows/movie86.yaml` at the repo root. Runs on push/PR to `mov`: `cargo fmt --check`, `cargo clippy --all-targets -D warnings`, `cargo test --workspace --all-targets`, and a `wasm32-unknown-unknown` build of `movie86-core`. Actions pinned to `vMAJOR.MINOR.PATCH` per project convention.
