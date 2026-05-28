# DESIGN.md

Design / architecture document for `llvm-mov`. Operating-model
decisions, pipeline shape, file layout, and the staged plan that
gets us from "scalar `ret i32 0`" to "fully mov-only `.text`".
For working conventions (TDD, dependency pins, when to use which
gate) see [`CLAUDE.md`](CLAUDE.md) — this file is design-only.

A real out-of-tree LLVM backend (`Target`) that lowers LLVM IR to
**x86-32 assembly that is eventually mov-only** — same intent as
[movfuscator](https://github.com/xoreaxeaxeax/movfuscator), rebuilt on
top of LLVM (`RegisterTargetMachine`, `llc`-driven).

This is **not** a transpiler that consumes textual `.ll` and emits asm.
The word "backend" is used in the strict LLVM sense: a `Target`
registered with the CodeGen pipeline.

## Operating model

Two things shape every decision here:

1. **The ISA model and the printed syntax are separated on purpose.**
   The target's TableGen instruction set is the eventual mov-only ISA,
   but the `AsmPrinter` emits **x86-32 GAS-syntax text**, so the result
   is assembled by stock `as --32` and linked by `ld -m elf_i386`. This
   keeps the toolchain dependency to LLVM + binutils only, and lets
   the first execution test be wall-clock cheap. Don't merge the two —
   a separate "mov-only legalization" pass at stage 7 is what enforces
   the mov-only constraint, not the printer.

2. **Execution-first TDD.** The primary signal is "fixture exits with
   the expected code". That's [`test/Execution/`](test/Execution/).
   lit + FileCheck on asm shape ([`test/CodeGen/`](test/CodeGen/))
   comes in as a second layer once a feature stabilises.
   Byte-identical golden testing (the movfuscator-wasm flavour) is
   **not** the primary gate here — backends drift legitimately during
   bootstrap and golden noise drowns the signal.

## Pipeline

```
.ll ──llvm-mov-llc──> .s ──as --32──> .o ──ld -m elf_i386──> ELF32
                          │                                     │
                          └──→ test/CodeGen lit+FileCheck       └──→ test/Execution exit-code
```

- `llvm-mov-llc` ([`tools/llvm-mov-llc/`](tools/llvm-mov-llc/)) is a
  **self-contained driver** built against `libLLVM-22`. It does what
  `llc -mtriple=mov-...` would do, *without* depending on `llc --load`
  (which is fragile across distro builds). One small `main.cpp` that
  registers our `MovTarget`, parses the IR, and runs
  `addPassesToEmitFile`.
- `as --32` / `ld -m elf_i386`: stock binutils. Static link, `_start`
  synthesised by the test driver (an inline `int 0x80` exit stub), so
  we don't depend on the CI runner's 32-bit dynamic loader.

## Layout

```
llvm/
  Mov.td               top-level TableGen
  MovRegisterInfo.td   EAX..EDI + GPR32 class
  MovInstrInfo.td      MOV32ri, MOV32rr, RET, JMP_4 placeholders
  MovCallingConv.td    cdecl-ish, return in EAX
  Mov*.{h,cpp}         TargetMachine / Subtarget / FrameLowering / ISelLowering / AsmPrinter
  MovOnlyLegalize.cpp  stage-7 mov-only legalization pass
  TargetInfo/          RegisterTargetMachine entry point → LLVMMovInfo
  MCTargetDesc/        MCAsmInfo + MCInstrInfo + MCRegisterInfo + InstPrinter → LLVMMovDesc
tools/
  llvm-mov-llc/        self-contained driver, see above → bin/llvm-mov-llc
test/
  Execution/           .ll fixtures + run.sh — main TDD signal
  CodeGen/             lit + FileCheck (later)
  MovOnly/             objdump gate for stage 7+ (.text contains only mov-family)
examples/
  rust/main/, rust/fib/  Cargo crates demonstrating Rust → mov-only ELF
bench/
  fixtures/, run.sh, results.md  side-by-side vs movfuscator
```

## ABI / frame convention by stage

- **Frameless leaf functions at stage 2.** `MovFrameLowering` emits
  no prologue/epilogue and `CSR_Mov` is empty. Formal args are read
  directly from `[esp + n]` via fixed `MachineFrameInfo` objects whose
  SP-relative offsets are `4 + LocMemOffset` (the `+4` accounts for
  the return address `call` pushes). `eliminateFrameIndex` rewrites
  FrameIndex operands to `(ESP, off)` with no SP adjustment.
- **EBX/ESI/EDI/EBP reserved through stage 3** (in
  `MovRegisterInfo::getReservedRegs`): the cdecl callee-saved set,
  reserved because `CSR_Mov` is empty and prologue/epilogue are no-op
  — leaving them allocatable would let RA silently clobber the caller.
  Reserving them constrains stage 3 arithmetic to `EAX/ECX/EDX`
  (plenty for the current fixtures). The reservation drops at the
  same commit that lands prologue/epilogue (stage 4).
- **EBP-based frame, prologue, CSR re-enable land together at stage 4.**
- **All stage 3 binops are 2-address** (`Constraints = "$src1 = $dst"`).
  x86 `add reg, src` is `dst = dst + src`, not `dst = src1 + src2`;
  without the tie, RA freely picks distinct physical regs for `$src1`
  and `$dst` and the emitted asm is wrong. The `BinOpRR`/`BinOpRI`/
  `ShiftRI` helper classes enforce this — any new mov-heavy binop
  should go through them so the tie can't be forgotten.

### Stack-slot coloring with cdecl arg slots

LLVM Stack Slot Coloring will merge alloca slots with cdecl arg slots
whenever the alloca is the only user of the i32 value the caller
pushed. cdecl allows callee to scribble its arg slots, so SSC rewrites
the alloca's FrameIndex to `%fixed-stack.0` and the asm ends up
writing to `[ebp + 8]` instead of `[ebp - 4]`. This is a legal
optimisation, but it means the obvious `define i32 @rmw(i32 %x) {
alloca; store %x; ...; load; ret }` shape does *not* cover the
local-slot codepath. To exercise it, use a no-arg fixture (or one
whose alloca lifetime provably overlaps with the arg slot's).
`test/Execution/rmw.ll` is the no-arg version that does land at
`[ebp - 4]`; `spill_chain.ll` exercises PEI-allocated spill slots.

## Stage 7 — mov-only legalization

The `MovOnlyLegalize` `MachineFunctionPass` ([`llvm/MovOnlyLegalize.cpp`](llvm/MovOnlyLegalize.cpp))
runs in `addPreEmitPass` (after RA, after PEI, after BranchFolder) and
turns every non-mov instruction the earlier stages emitted into a
mov-only sequence. Staged so each commit lands one legalize-target
opcode at a time.

### 7a / 7b — local rewrites (per-MI, deterministic)

No CFG or ABI changes. Each commit replaces one MachineInstr with a
short mov-only chain that uses pre-PEI-reserved scratch slots.

- **7a0** ships the empty pass + `addPreEmitPass` wiring + `make
  test-mov-only` gate. No fixtures yet.
- **7a1** is the first real legalization: `ADD32r{r,i}` via a
  **byte-chain carry table** — `__mov_add8_sum_table[cin][a][b]` +
  `__mov_add8_carry_table[cin][a][b]`, 128 KiB each, indexed by an
  8-bit register held in `CL`/`AL`/etc.; the four byte additions are
  chained via `mov` of the carry between them. Required
  prerequisites in **stage 7-prep-2**:
  - **2a** hand-written `.byte` table emission in
    `MovAsmPrinter::emitEndOfAsmFile`.
  - **2b** new index-register mem operand kind + a legalize-only
    `MOV8rm_idx` patternless instruction for `[base + index]` table
    lookup.
  - **2c** post-RA scratch-slot helper (purpose-keyed
    `getOrCreateScratchSlot`) to spill parent regs when `CL`/`AL` is
    needed but `ECX`/`EAX` is live.
  Earlier drafts mentioned an "i32-cell" lookup that avoided MOV8 —
  that path turned out not to actually skip byte extraction, so the
  byte-chain is canonical.
- **7b1** = AND / OR / XOR via the corresponding byte tables.
- **7b2** = SHL / SHR / SAR by immediate (separate from logic because
  shift carry / bit-extraction is a different table shape).
- **7b3** = SHL / SHR / SAR by `CL` (variable shift via 5-stage
  power-of-2 unroll).

### 7c — control-flow legalization (CFG-level)

- **7c0** substrate for a branchless dispatcher (no rewrite yet).
- **7c1** the CFG rewrite itself: every BB ends with `mov [next_pc],
  <target>; jmp .Ldispatcher`. The dispatcher MBB at the function end
  holds a single `JMP32m [ebp + next_pc_disp]`.
- **7c2** CMP+Jcc(E/NE) → mov-only via byte XOR + OR-reduce +
  select_mask_table.
- **7c3** CMP+Jcc(B/AE/BE/A) (unsigned) → byte SUB chain with borrow.
- **7c4** CMP+Jcc(L/GE/LE/G) (signed) → adds SF + OF flag math on
  top of the 7c3 SUB chain.

Codex's flagged stage-7 trap: do **NOT** start with movfuscator's
segment-register-self-modification trick — Linux ELF section
permissions (W^X), late-MI CFG invariants, and the `Jcc`/`CALL`/`RET`
terminator-class machinery all collide there. The 7c dispatcher
above sidesteps all of that.

### 7d — ABI legalization (call/ret/push/pop/sub)

- **7d0** `SUB32ri` (incl. prologue `sub esp, K`) via the 7c3 sub8
  byte chain. A page-budget guard bails out when the scratch slot
  offset crosses a 4 KiB page (large-frame correctness — without it
  the byte chain's scratch writes can fault on a guard page before
  ESP has been adjusted).
- **7d1** `pop ebp + ret` (epilogue tail) as a single unit via a new
  global `.bss.__mov_return_addr_slot`. Each ret writes its own RA
  into the slot then immediately jumps via `JMP32m [ecx]` — one slot
  is safe because writes are sequential, never concurrent. Splitting
  RET legalize from the `pop ebp` is fragile because `pop ebp`
  destroys the EBP base our other rewrites use.
- **7d2** `push ebp` (prologue head) via a separate global
  `.bss.__mov_esp_dec_scratch`. At the entry MI EBP still holds the
  caller's frame pointer, so `[ebp + scratch]` would resolve into the
  caller's frame — we use EAX-relative addressing into the global slot
  instead.
- **7d3** `CALL32d` → MBB-split + `JMP32d_CALL` direct jump. The
  continuation MBB owns the return-address label (its symbol is what
  the callee's 7d1 jumps back to via `__mov_return_addr_slot`).
  CALL32d's regmask + caller-clobber implicit defs are transferred to
  the new JMP32d_CALL so late liveness analysis still sees the call's
  clobber semantics — critical for `call_live_across` shapes.

### 7e / 7f — bit-twiddling + multiply/divide

- **7e** CTPOP / CTLZ / CTTZ via 256-entry byte tables
  (`__mov_popcount8_table`, `__mov_ctlz8_table`, `__mov_cttz8_table`)
  + the existing add8 accumulator for popcount.
- **7f1** 32-bit MUL via `MUL32{rr,ri}` pseudos + byte-pair schoolbook
  multiplication using `__mov_mul8_{lo,hi}_table` (two 64 KiB tables
  in `.rodata.__mov_mul8_tables`). ~437 mov / call site.
- **7f2** 32-bit UDIV / SDIV / UREM / SREM via SDAG Expand → libcall,
  with `llvm-mov-llc` injecting the four compiler-rt-named helper
  bodies (`__udivsi3 / __umodsi3 / __divsi3 / __modsi3`) as IR when
  the input module contains any div/rem instruction. The helpers
  are emitted with `linkonce_odr` linkage so multiple TUs each
  carrying them don't conflict; the linker keeps one definition.
  `__udivsi3` is a 32-iter restoring long division with a single
  branchless body; the signed helpers do an abs-then-udiv-then-fixup
  dance. Per-site cost in `.text` is one `call` (already mov-only
  via 7d3) + the helper body amortised across all div/rem callers
  in the ELF.

  Why driver IR injection and not a `DIV32rr` byte-chain pseudo (the
  shape 7f1 used for MUL): bit-by-bit long division would emit
  ~16000 movs per call site (32 iters × ~500 movs each), the same
  cost as the libcall path's body. With no compaction win, injection
  keeps `.text` linear in user-call count and removes the user-crate
  compiler-rt stubs that base64_decode / qoi_decode previously
  shipped. The injection runs before the driver-level i32 SELECT →
  bit-blend rewrite so the helper's `r >= d ? r - d : r` shape is
  rewritten to straight-line ops instead of branching (the SELECT
  → branch shape is what historically forced DAG-ISel into the
  multi-minute legalize loop the SELECT-rewrite was introduced to
  avoid).

  Side fixes that 7f2 required:
  - **SUB32rr** mov-only legalize (`legalizeSUB32rr`) — same shape
    as `legalizeADD32rr` but indexing `__mov_sub8_{diff,borrow}_table`.
    The helper bodies need `r - d` and several abs / sign-fixup
    subs; before 7f2 only SUB32ri was covered.
  - **CMP+Jcc matcher** in `legalizeCmpJccPairs` relaxed to skip
    any EFLAGS-preserving instruction (in particular, register-
    allocator-inserted COPYs around PHI lowering) between the CMP
    and the Jcc, instead of bailing out the moment a non-MOV32mi
    appears. The pattern was tight enough that hand-written
    fixtures matched but the helpers' loop-with-PHI bodies, which
    RA spills around, did not.

### Stage 7 gates

[`test/MovOnly/run.sh`](test/MovOnly/run.sh) is the objdump gate.
Whitelist: `mov`, `movabs`, `movzx`, `movsx`. Anything else in a
fixture's `.text` is a FAIL by default. A fixture can opt into
additional accepted opcodes via a per-fixture `<name>.expect` file
(used during the bootstrap so a fixture lands at stage 7a1 even
though stage 7d hasn't run yet, then `.expect` shrinks as each
later stage ships).

`_start.s` is never disassembled (it owns the only `int 0x80`).

After stage 7d the remaining non-mov mnemonics across the bench
fixtures are exactly `call int jmp` — `call`/`int 0x80` in `_start`
(allowed runtime escape), `jmp` from the 7c1 dispatcher + 7d1
return-jmp + 7d3 `JMP32d_CALL` (all mov-equivalent indirect/direct
branches the gate accepts).

## Goals (committed)

- An `examples/rust/` flow: `cargo rustc --emit=llvm-ir` →
  `llvm-mov-llc` → ELF. Two Cargo crates today
  ([`examples/rust/main/`](examples/rust/main/),
  [`examples/rust/fib/`](examples/rust/fib/)), both `no_std`,
  `panic=abort`, edition 2024.
- A `bench/` comparing this backend against movfuscator on shared
  fixtures — binary size, mov instruction count, runtime. LLVM's
  optimiser is much stronger than LCC's, so the question "can we
  produce **smaller** mov-only binaries than the LCC-era movfuscator"
  is a first-class research question for this project, not a stretch
  goal. Side-by-side numbers in [`bench/results.md`](bench/results.md).

## Further reading

- [Writing an LLVM Backend](https://llvm.org/docs/WritingAnLLVMBackend.html)
- [Code Generator Overview](https://llvm.org/docs/CodeGenerator.html)
- [Building LLVM with CMake](https://llvm.org/docs/CMake.html)
- The movfuscator-wasm sibling: [`../movfuscator-wasm/`](../movfuscator-wasm/)
