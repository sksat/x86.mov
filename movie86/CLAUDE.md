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

**Confirmed by the new debug tooling (`movie86 --watch <addr>`):** `external` (`0x08686194` in our test build) is **never written** during the entire run. Hypothesis 1 ("runtime self-modifies `external` before each dispatch") is dead.

Also confirmed by `--break-at`:
- main starts running at step 102 (entry → crt0 → main).
- `mov cs, ax` at `0x08049d6e` fires at step 625. That address sits **inside main's body** (it ends at `0x08049d68` per objdump; the dispatch is 6 bytes past the end). So this dispatch is main's exit / return mechanism, not a libc-call trampoline.

That makes hypothesis 2 (a richer C SIGSEGV handler that reads `ucontext` to recover EAX and stuff it into `external`) the leading remaining candidate — but movfuscator's `sigaction` call uses `SA_NODEFER` and a `void(int)` handler signature, so the bare `dispatch` we see can't access `ucontext`. There's something else going on, possibly:
- A different signal handler than the one we identified (maybe a wrapping libc function).
- A layout trick where `external` is the same address as some other heavily-written symbol — though `nm` says no.
- The whole site is a deliberate "kill the process" pattern that real Linux turns into program termination, expecting the kernel's default SIGSEGV behavior to fire.

Tooling needed to dig in: `cd movfuscator-wasm && make setup && make build-native` to materialize the runtime objects (gitignored under `vendor/movfuscator/build/`).

## CI

`.github/workflows/movie86.yaml` at the repo root. Runs on push/PR to `mov`: `cargo fmt --check`, `cargo clippy --all-targets -D warnings`, `cargo test --workspace --all-targets`, and a `wasm32-unknown-unknown` build of `movie86-core`. Actions pinned to `vMAJOR.MINOR.PATCH` per project convention.
