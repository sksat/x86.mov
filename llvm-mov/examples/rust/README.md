# examples/rust — Rust → mov-only x86-32 (stage 6.5)

End-to-end pipeline:

```
main.rs ──rustc --emit=llvm-ir──> .ll ──llvm-mov-llc──> .s ──as --32──> .o ──ld -m elf_i386──> ELF32
                                                                                                │
                                                                                                └─→ exit 42
```

[`main.rs`](main.rs) is a `#![no_std]` `#![no_main]` `panic=abort` crate
that exposes a single `extern "C" fn rust_main() -> i32 { 42 }`.
[`_start.s`](_start.s) calls it and `int 0x80`s with the return value.
[`run.sh`](run.sh) drives the whole pipeline.

## Why this works (and what to expect)

This isn't a "Rust frontend" — we're just demonstrating that the Mov
backend can already consume a minimal slice of rustc-generated LLVM IR.
The pipeline rests on three load-bearing constraints:

1. **`-mtriple=mov-unknown-linux-gnu` is mandatory.** Rustc emits the
   `i686-unknown-linux-gnu` triple with data layout
   `e-m:e-p:32:32-...-S128`. Our backend uses `...-S32` and a slightly
   different pointer-bank shape. The driver refuses implicit triple
   mismatches but honours explicit `-mtriple` as a retarget request,
   at which point it overwrites the layout with ours. The fixture stays
   within IR shapes that don't depend on the difference (scalar `i32`
   return, no aggregates, no FP).
2. **Tight Rust surface.** No std, no panic message formatting, no
   atomics, no aggregates, no FP. The function must be `extern "C"`
   and return a single scalar. Anything richer hits IR shapes the Mov
   backend doesn't yet lower (struct return → post-stage-7,
   floats/atomics/inline-asm → out of scope).
3. **Static link, no libc.** `_start.s` invokes `int 0x80` directly,
   sidestepping the host's 32-bit dynamic loader and crt0 entirely
   (same approach as the rest of `test/Execution/`).

## Running it

```sh
# One-time toolchain prerequisite (~10 MB precompiled rlibs):
rustup target add i686-unknown-linux-gnu

# From the llvm-mov/ root:
make build                # builds llvm-mov-llc
make test-rust-example    # runs examples/rust/run.sh --run
```

`run.sh` without arguments prints the generated asm and `file` output
of the linked ELF without executing it; pass `--run` to actually
launch the linked binary and surface its exit code.

Sample asm for `rust_main`:

```
rust_main:
    push    ebp
    mov     ebp, esp
    mov     eax, 42
    mov     esp, ebp
    pop     ebp
    ret
```

The crate also emits an implementation of
`__rustc::rust_begin_unwind` (Rust's panic-abort hook), which compiles
to `push ebp; mov ebp, esp; jmp self`. We don't reach it from
`rust_main`, so the loop is harmless dead code in the linked ELF.

## What grows next

- `extern "C" fn rust_main(x: i32) -> i32 { x + 1 }` lands as soon as
  the example takes a CLI-passed arg.
- Multi-function Rust (one Rust fn calling another) is already
  supported by stage 6a's direct-call lowering — adding a fixture
  here is just a matter of writing the Rust.
- Richer Rust (collections, formatting, allocator) waits for a much
  larger backend surface.
