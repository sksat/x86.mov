# CLAUDE.md

Meta development guidance for working in this directory. Conventions,
gates, dependency pins, gotchas you can't infer from reading the code.
For the project's design — operating model, pipeline shape, file
layout, the staged stage-7 plan — see [`DESIGN.md`](DESIGN.md).

## Conventions

- **Execution-first TDD.** The primary signal is "fixture exits with
  the expected code". That's [`test/Execution/`](test/Execution/).
  lit + FileCheck on asm shape ([`test/CodeGen/`](test/CodeGen/))
  comes in as a second layer once a feature stabilises.
  Byte-identical golden testing (the movfuscator-wasm flavour) is
  **not** the primary gate here — backends drift legitimately during
  bootstrap and golden noise drowns the signal.
- **The previous shortcut is closed.** This is **not** a transpiler
  that consumes textual `.ll` and emits asm. A prior attempt to
  bootstrap as a Rust-based `.ll → asm` tool was scrapped; don't
  reintroduce that shortcut (see top-level memory
  `feedback-llvm-backend-terminology`). "Backend" here means a real
  LLVM `Target` registered with the CodeGen pipeline.

## Test gates (in the order they should pass)

| make target | what it asserts | dependency |
|---|---|---|
| `make build` | `llvm-mov-llc` compiles against `libLLVM-22` | LLVM 22.1.x (apt.llvm.org) |
| `make test` | 39 [`test/Execution/`](test/Execution/) fixtures exit with their expected codes | binutils `as --32`, `ld -m elf_i386` |
| `make test-mov-only` | every [`test/MovOnly/`](test/MovOnly/) fixture's `.text` contains only mov-family mnemonics (plus per-fixture `.expect` allowlist) | (same) |
| `make test-rust-example` | plain `cargo build --release` in every crate under [`examples/rust/*/`](examples/rust/) produces a runnable mov-only ELF (alias: `make test-cargo-build`; harness at [`test/CargoBuild/run.sh`](test/CargoBuild/run.sh)) | rustc + cargo + `rustup target add i686-unknown-linux-gnu` |
| `make bench` | regenerates [`bench/results.md`](bench/results.md) (side-by-side vs movfuscator + Rust rows) | clang-22, hyperfine, movfuscator |
| `make bench-check` | committed `results.md` deterministic numbers still match a fresh run | (same) |

## Workflow gotchas

- **LLVM version pin**: targeting **22.1.x**. Distro `apt` doesn't
  have ≥20, so we depend on [apt.llvm.org](https://apt.llvm.org/).
  CI installs via `llvm.sh 22`. Local dev needs the same. When
  bumping, expect CodeGen surface tweaks — out-of-tree backends
  touch a lot of semi-public LLVM API.
- **TableGen reruns on every build**: the `tablegen()` macro in
  CMake produces `MovGen*.inc` under `build/llvm/`. Stale `.inc`
  files mean rebuild from scratch (`rm -rf build`).
  `MovCommonTableGen` is the umbrella DEPENDS target.
- **Don't depend on `llc --load`**: the apt-installed `llc-22`
  doesn't reliably accept out-of-tree target plugins (stripped /
  unstable symbols, link form differs across distro builds). Always
  go through the self-contained `llvm-mov-llc` driver instead.
- **`_start.s` is synthesised per-fixture**, not checked in. The
  test runner ([`test/Execution/run.sh`](test/Execution/run.sh))
  generates one on the fly: by default calls `main()`; if a
  `<name>.callargs` file exists, the runner parses its
  `<func> [args…]` line and pushes the args cdecl-style before
  `call`. Then `mov ebx, eax; mov eax, 1; int 0x80` exits. This
  sidesteps the runner's 32-bit dynamic loader, glibc CRT, etc.
  Don't try to upgrade to a libc-linked binary before stage 6.

## Coding rules that the design *can't* infer for you

- **Stages 0–6 are allowed to emit `jmp/call/ret/cmp`.** The
  dedicated `MovOnlyLegalize` `MachineFunctionPass` at stage 7 is
  what eliminates them. Don't preemptively encode mov-only patterns
  into TableGen — it'll slow every other stage and tangle the
  fast-path / slow-path split.
- **All stage-3 binops are 2-address.** Use the `BinOpRR`/`BinOpRI`/
  `ShiftRI` helper classes in [`MovInstrInfo.td`](llvm/MovInstrInfo.td)
  — they bake in `Constraints = "$src1 = $dst"` so the tie can't be
  forgotten. (Without the tie RA freely picks distinct physregs for
  `$src1` and `$dst` and the emitted asm is wrong.)
- **Don't preempt segment-register self-modification.** Codex's
  flagged stage-7 trap: do not port movfuscator's segment-register
  trick. Linux ELF section permissions (W^X), late-MI CFG
  invariants, and the `Jcc`/`CALL`/`RET` terminator-class machinery
  all collide. The 7c branchless dispatcher already sidesteps it —
  see [`DESIGN.md`](DESIGN.md) §"Stage 7 — mov-only legalization".

## When in doubt, read

- [`DESIGN.md`](DESIGN.md) for the architecture / staged plan.
- [`bench/results.md`](bench/results.md) for the current bench
  numbers (auto-generated; committed for diffability).
- Top-level [`CLAUDE.md`](../CLAUDE.md) for repo-wide conventions
  (TDD, subproject layout).
