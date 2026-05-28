# examples/rust — Rust → mov-only x86-32

End-to-end pipeline, invoked by a plain `cargo build --release`:

```
src/main.rs ──rustc --emit=llvm-ir──> .ll ──llvm-mov-llc──> .s ──as --32──> .o ──ld -m elf_i386──> ELF32
                                                              (linker driver: cargo-link.sh)
```

[`./.cargo/config.toml`](.cargo/config.toml) rewires every crate under
this directory to go through [`cargo-link.sh`](cargo-link.sh) at the
link step. Rustc emits the LLVM IR (via `--emit=llvm-ir`) instead of a
native binary; the driver picks the `.ll` up, runs `llvm-mov-llc`, and
calls `as --32` + `ld -m elf_i386 -static` to produce the final mov-only
ELF where cargo expects its binary output.

Result: `cd <crate> && cargo build --release` is the whole command —
no `run.sh` wrapper required. Each crate is an independent Cargo
project with its own deps:

| crate | entry | stage exercised | expected exit |
|---|---|---|---:|
| [`main/`](main/) | `rust_main` | 6.5 (trivial scalar return) | 42 |
| [`fib/`](fib/) | `fib_main` | 7d1 + 7d3 (recursion through global return-addr slot) | 32 |
| [`png_header/`](png_header/) | `png_header_main` | 6d3a (`load i32, align 1`) | 8 |
| [`jpeg_header/`](jpeg_header/) | `jpeg_header_main` | 6d3a + marker walk | 16 |
| [`bmp_decode/`](bmp_decode/) | `bmp_decode_main` | 6d3a full 32bpp decode | 104 |
| [`base64_decode/`](base64_decode/) | `base64_decode_main` | 6d3c crates.io ecosystem (base64) | 105 |
| [`qoi_decode/`](qoi_decode/) | `qoi_decode_main` | 6d3e crates.io ecosystem (qoi) | 8 |
| [`aes/`](aes/) | `aes_main` | stage 8+ blocker (vector.reduce.xor) | n/a |

All crates are edition **2024** (`#[no_mangle]` → `#[unsafe(no_mangle)]`),
`#![no_std]` + `#![no_main]`, and target `i686-unknown-linux-gnu`.
The shared [`run.sh`](run.sh) driver is a thin dev wrapper around
`cargo build`; pick a crate via `--example=<dir>` for a quick build +
asm dump or `--run` to also execute the binary and check its exit code.

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
   `#![no_std]` + `#![no_main]` attributes in each `src/main.rs`
   enforce this.
4. **Static link, no libc.** Each crate's `_start.s` invokes `int 0x80`
   directly, sidestepping the host's 32-bit dynamic loader and crt0
   entirely (same approach as `test/Execution/`). `cargo-link.sh`
   ignores rustc's native `.o` and the runtime libs it would normally
   pull in — only the crate's `.ll` (run through `llvm-mov-llc`),
   `_start.s`, and any dependency `.o` extracted from rlibs end up in
   the final ELF.

## Running

```sh
# One-time toolchain prerequisite (~10 MB precompiled rlibs):
rustup target add i686-unknown-linux-gnu

# From the llvm-mov/ root:
make build                              # builds llvm-mov-llc

# Plain cargo build per example:
cd examples/rust/main && cargo build --release
./target/i686-unknown-linux-gnu/release/rust-mov-main; echo $?    # → 42

# Or, dev wrapper (build + run + exit-code check, one of the 7 crates):
bash examples/rust/run.sh --example=fib --run     # → PASS  fib_main  (exit 32)

# Full CI gate — `cargo build` every example, check every exit code:
make test-rust-example   # alias: make test-cargo-build
```

Omit `--run` in the dev wrapper to dump the generated asm + `file`
output of the linked ELF without executing it. The asm lives under
`<crate>/target/i686-unknown-linux-gnu/release/deps/<crate>-<hash>.s`
since the linker driver writes it next to its `-o` target.

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
