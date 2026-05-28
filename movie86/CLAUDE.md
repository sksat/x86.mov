# CLAUDE.md

Dev-process file for movie86. Keep this short. Architecture, ABI
decisions, demos, investigation notes → [`DESIGN.md`](DESIGN.md). Read
that one first if you're touching code and want to know *why* something
is shaped the way it is.

## TDD style

- New instructions: unit decoder test (byte sequence → expected `Insn`), executor test (run a 1-insn program, assert register/memory effects), and where useful a property test (proptest dev-dep). PBT is especially valuable for catching encoding/semantic asymmetries — for `mov r32, r32` we have a property over all 64 (dst, src) pairs.
- Adding a `Fault` variant: prefer trapping early with a distinct variant over reusing an existing one. `Unmapped(eip)` from `fetch` and `DecodeTruncated` from `decode` were merged in an early version and codex's review caught it — they hide different real bugs.
- 8-/16-bit register aliasing semantics (`AH`/`AL` over `EAX`) is the easiest place to introduce a subtle bug. Tests pin the aliasing explicitly: writing `AH` should leave bits 7:0 alone; writing `AL` should leave bits 31:8 alone.

## Things future Claude shouldn't relearn

- **The address-space rejection is at `FlatMemory::new_zeroed`, not at access time.** Construction-time rejection keeps the access path simple. If you find yourself wanting to allow regions past `0xffff_ffff`, you've probably written a bug.
- **`Reg32::Esp == 4` collides with the SIB-byte sentinel** when `r/m == 4` under `mod != 11` — that's why the decoder routes through `parse_sib_address` before treating `r/m` as a register. Likewise `r/m == 5` under `mod == 00` means "disp32, no base" (not EBP); under `mod == 01/10` it's EBP + disp. The Intel SDM Vol. 2A Table 2-3 sentinels are easy to forget.
- **The CLI's `StdHost` only knows `exit(1)` and `write(4)`** for syscalls; libc functions go through a separate `LibcHost` trait (`int 0x81`, cdecl). Adding a syscall means adding an arm to `StdHost::syscall` and (probably) a regression test in `cli/tests/e2e.rs`. Don't silently extend the syscall set in `core` — the trait pair is the seam.
- **`vec![0; N]` not `Vec::new(); resize(N, 0)`** — clippy's `slow_vector_initialization` catches the difference. Comes up in test helpers that build ELF bytes.
- **Run `cargo fmt --all` before pushing.** CI enforces `cargo fmt --all -- --check`; clippy + test alone aren't enough.

## CI

`.github/workflows/movie86.yaml` at the repo root. Runs on push/PR to `mov`: `cargo fmt --check`, `cargo clippy --all-targets -D warnings`, `cargo test --workspace --all-targets`, and a `wasm32-unknown-unknown` build of the `movie86` library crate. Actions pinned to `vMAJOR.MINOR.PATCH` per project convention.
