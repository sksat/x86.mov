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

## CI

`.github/workflows/movie86.yaml` at the repo root. Runs on push/PR to `mov`: `cargo fmt --check`, `cargo clippy --all-targets -D warnings`, `cargo test --workspace --all-targets`, and a `wasm32-unknown-unknown` build of `movie86-core`. Actions pinned to `vMAJOR.MINOR.PATCH` per project convention.
