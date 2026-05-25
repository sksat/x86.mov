# llvm-mov

An out-of-tree LLVM backend (`Target`) that lowers LLVM IR to **x86-32 assembly that
eventually uses only `mov` instructions**, inspired by
[movfuscator](https://github.com/xoreaxeaxeax/movfuscator) but rebuilt as a real
LLVM `Target` (registered via `RegisterTargetMachine`, driven by `llc`).

```
.ll ──llc / llvm-mov-llc──> .s ──as --32──> .o ──ld -m elf_i386──> ELF32
                                                                    │
                                                                    └─→ exit code 0
```

The triple is `mov-unknown-linux-gnu`. The ISA model is its own (mov-only
in the limit), but the printer currently emits **x86-32 GAS-syntax text asm**, so
the result is assembled by stock `as`/`ld`.

## Status

Bootstrap. Goals listed in roughly increasing difficulty:

| stage  | scope                                              | gate                                                     | done? |
|--------|----------------------------------------------------|----------------------------------------------------------|-------|
| 0      | `define i32 @main() { ret i32 0 }`                 | linked ELF exits 0                                       | ✅    |
| 1      | `ret i32 <imm>` for any 32-bit constant            | exit code matches lower 8 bits                           | ✅    |
| 2      | one i32 argument, cdecl                            | call from a synthesised `_start` (see `test/Execution/run.sh`) | ✅ |
| 3      | i32 `add/sub/and/or/xor`, shift-imm                | execution tests (incl. 2-address chain coverage)         | ✅    |
| 3.5    | reg-shift (CL constraint), narrow-int promotion    | execution tests                                          |       |
| 4      | `alloca/load/store` on a local stack frame         | execution tests                                          |       |
| 5      | `icmp + br`                                        | execution tests + MIR tests                              |       |
| 6      | `call` between user-defined functions              | execution tests                                          |       |
| 7      | mov-only legalization pass (compare/branch/arith)  | objdump gate: no non-`mov` opcodes in `.text`            |       |
| 8      | bigger fixtures (movfuscator's `upstream-*` set)   | side-by-side bench vs movfuscator                        |       |

At stage 0–6 the emitter is "mov-heavy" — `jmp/call/ret/cmp` are still allowed.
At stage 7 the dedicated legalization pass eliminates them. Splitting that wall
in two is intentional: it lets the compiler skeleton stabilise before the
mov-only constraint dominates every decision.

## Layout

```
llvm-mov/
  llvm/                  the backend itself → LLVMMovCodeGen + LLVMMovDesc + LLVMMovInfo
    Mov.td               top-level TableGen
    Mov*.td              register / instruction / calling-conv .td
    Mov*.{h,cpp}         TargetMachine, Subtarget, FrameLowering, ISelLowering, AsmPrinter…
    TargetInfo/          RegisterTargetMachine entry point
    MCTargetDesc/        MC layer (MCAsmInfo, MCInstrInfo, MCRegisterInfo, InstPrinter)
  tools/
    llvm-mov-llc/        self-contained driver — same job as `llc -mtriple=mov-…`
                         but doesn't depend on stock `llc --load` (which is fragile)
  test/
    Execution/           .ll → built ELF → run → assert exit code
    CodeGen/             lit + FileCheck, asserts on emitted asm shape
  examples/
    rust/                rustc --emit=llvm-ir → llvm-mov-llc → ELF (planned)
  bench/                 side-by-side vs movfuscator (planned)
  CMakeLists.txt
  Makefile               single entry point (mirrors movfuscator-wasm conventions)
```

## Prerequisites

This backend targets LLVM **22.1.x**. On Debian 13 / Ubuntu 24.04 the distro
`apt` only ships up to LLVM 19, so you need the official
[apt.llvm.org](https://apt.llvm.org/) repo:

```sh
wget -qO- https://apt.llvm.org/llvm.sh | sudo bash -s -- 22
sudo apt-get install -y \
    llvm-22-dev clang-22 lld-22 \
    cmake ninja-build \
    gcc-multilib libc6-dev-i386
```

Why LLVM 22: bumping in lockstep with upstream is cheap *before* the backend
has shape; pinning early would just lock us behind. Once the codegen surface
stabilises we will pin to a specific `22.1.<patch>`.

## Quick start

```sh
make build         # cmake -B build && ninja -C build
make test          # runs the execution test suite
make test-codegen  # lit + FileCheck over test/CodeGen
```

`build/bin/llvm-mov-llc` is the driver:

```sh
echo 'define i32 @main() { ret i32 0 }' \
  | build/bin/llvm-mov-llc -o -
```

## TDD workflow

The first signal is **execution**: build an `.ll` fixture through
`llvm-mov-llc → as → ld`, run it, check the exit code. That's
[`test/Execution/`](test/Execution/).

The second signal is **codegen shape**: lit + FileCheck over the asm. That's
[`test/CodeGen/`](test/CodeGen/) — added once a feature's asm form is stable.

The third signal (planned for stage 7+) is the **mov-only gate**: parse
`build/bin/llvm-mov-llc` output with `objdump -d -Mintel` and assert no
instruction other than `mov` (and a small whitelist of structurally
unavoidable ones like `ret` while bootstrapping the legalization) appears in
`.text`.

## Relationship to movfuscator-wasm

[`../movfuscator-wasm/`](../movfuscator-wasm/) is the original
movfuscator (LCC + LCC's own mov backend) shipped as wasm. `llvm-mov` is
the independent reconstruction on top of LLVM — same idea, very different
mid/back-end. The two are kept in the same repo so we can run the same
fixtures through both and benchmark side-by-side
([`bench/`](bench/)).

## Further reading

- [Writing an LLVM Backend](https://llvm.org/docs/WritingAnLLVMBackend.html)
- [Building LLVM with CMake](https://llvm.org/docs/CMake.html) (look for
  `LLVM_EXTERNAL_PROJECTS` / out-of-tree builds)
- [movfuscator/the M/o/Vfuscator paper](https://github.com/xoreaxeaxeax/movfuscator)
