# examples/rust — Rust → mov-only x86-32

End-to-end pipeline:

```
src/lib.rs ──cargo rustc --emit=llvm-ir──> .ll ──llvm-mov-llc──> .s ──as --32──> .o ──ld -m elf_i386──> ELF32
```

Two independent Cargo crates live under this directory:

| crate | entry | stage exercised | expected exit |
|---|---|---|---:|
| [`main/`](main/) | `rust_main` | 6.5 (trivial scalar return) | 42 |
| [`fib/`](fib/) | `fib_main` | 7d1 + 7d3 (recursion through global return-addr slot) | 55 |

Both crates are edition **2024** (`#[no_mangle]` → `#[unsafe(no_mangle)]`)
and target `i686-unknown-linux-gnu`. The shared
[`run.sh`](run.sh) driver picks one via `--example={main,fib}`.

## Build invariants

1. **`-mtriple=mov-unknown-linux-gnu` is mandatory.** Rustc emits the
   `i686-unknown-linux-gnu` triple with data layout `e-m:e-p:32:32-…-S128`.
   Our backend uses `…-S32` and a slightly different pointer-bank shape.
   `llvm-mov-llc` refuses an implicit mismatch but honours an explicit
   `-mtriple` as a retarget request — at which point it overwrites the
   layout with ours. Each example deliberately stays within IR shapes
   that don't depend on those differences (scalar `i32` return,
   no aggregates, no FP).
2. **`panic = "abort"` + `overflow-checks = false`** in each crate's
   `[profile.release]`. The latter is what stops the integer subtractions
   in `fib` from lowering to `llvm.ssub.with.overflow.i32`, which would
   return an `{i32, i1}` aggregate the Mov backend doesn't yet handle.
3. **Tight surface.** `no_std`, no panic message formatting, no atomics,
   no aggregates, no FP. The Cargo profile knobs (above) plus the
   `#![no_std]` attribute in each `lib.rs` enforce this.
4. **Static link, no libc.** Each crate's `_start.s` invokes `int 0x80`
   directly, sidestepping the host's 32-bit dynamic loader and crt0
   entirely (same approach as `test/Execution/`).

## Running

```sh
# One-time toolchain prerequisite (~10 MB precompiled rlibs):
rustup target add i686-unknown-linux-gnu

# From the llvm-mov/ root:
make build                              # builds llvm-mov-llc

# Trivial example:
bash examples/rust/run.sh --example=main --run    # → PASS  rust_main  (exit 42)

# Recursive example:
bash examples/rust/run.sh --example=fib --run     # → PASS  fib_main   (exit 32)
```

Omit `--run` to dump the generated asm + `file` output of the linked
ELF without executing it.

## What it shows

Both binaries land **fully mov-only** in the user-side `.text`. The
only non-mov mnemonics are the `call int jmp` set we already accept
across the bench: `call` / `int 0x80` in `_start.s`, `jmp` from the
7c1 dispatcher + 7d1 return-jmp + 7d3 `JMP32d_CALL` terminators.

Approximate per-example sizes (clang `-O0` C reference shown for
context):

| binary | source | `.text` | mov / total |
|---|---|---:|---:|
| `examples/rust/main/` | Rust | 794 B | 193 / 199 (97.0 %) |
| `bench/fixtures/return0.c` | C | 488 B | 120 / 123 (97.6 %) |
| `examples/rust/fib/` | Rust | 3997 B | 984 / 998 (98.6 %) |
| `bench/fixtures/fib_rec.c` | C | 3720 B | 918 / 929 (98.8 %) |

Rust binaries trail C by ~7 % at the `fib` shape and ~60 % at the
trivial shape (the larger gap at `main` is the rustc-emitted panic
handler stub, which `--gc-sections` keeps because the symbol is
externally reachable). Both back-ends through `llvm-mov-llc` land
substantially smaller than `movfuscator`'s C-only output on the same
source (~3-4× smaller for `fib_rec`).

## What grows next

- Richer Rust (struct returns, slices, references) waits on aggregate
  + pointer-arithmetic lowering in the Mov backend.
- Adding a Cargo-based bench column would let the side-by-side table
  in [`bench/results.md`](../../bench/results.md) include Rust rows
  next to the existing C and movfuscator rows — open question whether
  the toolchain dependency is worth taking on in CI.
