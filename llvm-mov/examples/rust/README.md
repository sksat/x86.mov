# examples/rust — Rust → mov

**Planned.** Lands once the backend reaches stage 6 (function calls) — `ret` and
small arithmetic aren't enough to compile non-trivial Rust into something
worth showing.

The flow is intended to be:

```sh
rustc --emit=llvm-ir \
      --target=i686-unknown-linux-gnu \
      -O0 -Cpanic=abort \
      -o hello.ll hello.rs

../../build/bin/llvm-mov-llc \
      -mtriple=mov-unknown-linux-gnu \
      hello.ll \
      -o hello.s

as --32 -o hello.o hello.s
ld -m elf_i386 -static -e _start ../../test/Execution/_start.o hello.o \
      -o hello

./hello
echo "exit=$?"
```

Notes for future-me:

- `rustc` emits IR with `target triple = "i686-..."`. `llvm-mov-llc` now
  *refuses* to consume a non-Mov triple (see the bootstrap commit's
  code-review fix), so the example must pre-process the .ll with `sed`
  or use `-mtriple=mov-unknown-linux-gnu` and a matching data layout.
- The minimum no-std example should avoid panic, allocation, formatting —
  a `#[no_mangle] pub extern "C" fn main() -> i32` and an arithmetic
  expression is enough to demonstrate the pipeline.
- This example doubles as a stage-6 regression: if rustc ever emits IR
  shapes we don't lower, that's a stage-6 bug.
