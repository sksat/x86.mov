# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this directory.

A real out-of-tree LLVM backend (`Target`) that lowers LLVM IR to **x86-32 assembly that is
eventually mov-only** — same intent as [movfuscator](https://github.com/xoreaxeaxeax/movfuscator),
rebuilt on top of LLVM (`RegisterTargetMachine`, `llc`-driven).

This is **not** a transpiler that consumes textual `.ll` and emits asm. The word "backend"
is used in the strict LLVM sense: a `Target` registered with the CodeGen pipeline.
A previous attempt to bootstrap as a Rust-based `.ll → asm` tool was scrapped after
sksat objected — see [`feedback-llvm-backend-terminology`](../.claude/memory) (top-level
memory). Don't reintroduce that shortcut.

## Operating model

Two things shape every decision here:

1. **The ISA model and the printed syntax are separated on purpose.** The target's TableGen
   instruction set is the eventual mov-only ISA, but the `AsmPrinter` emits **x86-32 GAS-syntax
   text**, so the result is assembled by stock `as --32` and linked by `ld -m elf_i386`. This
   keeps the toolchain dependency to LLVM + binutils only, and lets the first execution test
   be wall-clock cheap. Don't merge the two — a separate "mov-only legalization" pass at stage
   7 is what enforces the mov-only constraint, not the printer.

2. **Execution-first TDD.** The primary signal is "fixture exits with the expected code".
   That's [`test/Execution/`](test/Execution/). lit + FileCheck on asm shape
   ([`test/CodeGen/`](test/CodeGen/)) comes in as a second layer once a feature stabilises.
   Byte-identical golden testing (the movfuscator-wasm flavour) is **not** the primary
   gate here — backends drift legitimately during bootstrap and golden noise drowns the signal.

## Pipeline

```
.ll ──llvm-mov-llc──> .s ──as --32──> .o ──ld -m elf_i386──> ELF32
                          │                                     │
                          └──→ test/CodeGen lit+FileCheck       └──→ test/Execution exit-code
```

- `llvm-mov-llc` ([`tools/llvm-mov-llc/`](tools/llvm-mov-llc/)) is a **self-contained driver**
  built against `libLLVM-22`. It does what `llc -mtriple=mov-...` would do, *without*
  depending on `llc --load` (which is fragile across distro builds). One small `main.cpp`
  that registers our `MovTarget`, parses the IR, and runs `addPassesToEmitFile`.
- `as --32` / `ld -m elf_i386`: stock binutils. Static link, `_start` synthesised by the
  test driver (an inline `int 0x80` exit stub), so we don't depend on the CI runner's
  32-bit dynamic loader.

## Layout

```
llvm/
  Mov.td               top-level TableGen
  MovRegisterInfo.td   EAX..EDI + GPR32 class
  MovInstrInfo.td      MOV32ri, MOV32rr, RET, JMP_4 placeholders
  MovCallingConv.td    cdecl-ish, return in EAX
  Mov*.{h,cpp}         TargetMachine / Subtarget / FrameLowering / ISelLowering / AsmPrinter
  TargetInfo/          RegisterTargetMachine entry point → LLVMMovInfo
  MCTargetDesc/        MCAsmInfo + MCInstrInfo + MCRegisterInfo + InstPrinter → LLVMMovDesc
tools/
  llvm-mov-llc/        self-contained driver, see above → bin/llvm-mov-llc
test/
  Execution/           ret_0.ll, run.sh — main TDD signal
  CodeGen/             lit + FileCheck (later)
```

## Things future Claude will likely need

- **LLVM version pin**: targeting **22.1.x**. Distro `apt` doesn't have ≥20, so we depend on
  [apt.llvm.org](https://apt.llvm.org/). CI installs via `llvm.sh 22`. Local dev needs the
  same. When bumping, expect CodeGen surface tweaks — out-of-tree backends touch a lot of
  semi-public LLVM API.
- **TableGen reruns on every build**: `tablegen()` macro in CMake produces
  `MovGen*.inc` under `build/llvm/`. Stale `.inc` files mean rebuild from scratch
  (`rm -rf build`). `MovCommonTableGen` is the umbrella DEPENDS target.
- **Don't depend on `llc --load`**: the apt-installed `llc-22` doesn't reliably accept
  out-of-tree target plugins (stripped/unstable symbols, link form differs). Always go
  through `llvm-mov-llc` instead.
- **Static `_start` for execution tests**: the test runner ([`test/Execution/run.sh`](test/Execution/run.sh))
  links a hand-written `_start` that calls `main` then issues `mov eax,1; mov ebx,<retval>;
  int 0x80`. This sidesteps the runner's 32-bit dynamic loader, glibc CRT, etc. Don't try
  to upgrade to a libc-linked binary before stage 6.
- **Where to stop adding "mov-only" hacks during bootstrap**: stages 0–6 are allowed to emit
  `jmp/call/ret/cmp`. The dedicated `MovOnlyLegalize` MachineFunctionPass at stage 7 is
  what eliminates them. Don't preemptively encode mov-only patterns into TableGen — it'll
  slow every other stage.

## Things sksat has explicitly asked for and is expecting

- An `examples/rust/` flow: `rustc --emit=llvm-ir` → `llvm-mov-llc` → ELF. Placeholder now,
  real once stage 6 (function calls) lands.
- A `bench/` comparing this backend against movfuscator-wasm on shared fixtures —
  binary size, mov instruction count, runtime. LLVM's optimiser is much stronger than LCC's,
  so the question "can we produce **smaller** mov-only binaries than the LCC-era movfuscator"
  is a first-class research question for this project, not a stretch goal.

## Further reading

- [Writing an LLVM Backend](https://llvm.org/docs/WritingAnLLVMBackend.html)
- [Code Generator Overview](https://llvm.org/docs/CodeGenerator.html)
- [Building LLVM with CMake](https://llvm.org/docs/CMake.html)
- The movfuscator-wasm sibling: [`../movfuscator-wasm/`](../movfuscator-wasm/)
