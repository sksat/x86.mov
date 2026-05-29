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

Through stage 7d3: `.text` of every user function across the 12 bench
fixtures (10 C + 2 Rust) is **fully mov-only**. The only non-mov
mnemonics in the linked ELF are `call int jmp` — `call` / `int 0x80`
in `_start.s` (the runtime escape, gate-accepted) and `jmp` from the
7c1 dispatcher + 7d1 return-jmp + 7d3 call-jmp.

| stage  | scope                                              | gate                                                     | done? |
|--------|----------------------------------------------------|----------------------------------------------------------|-------|
| 0      | `define i32 @main() { ret i32 0 }`                 | linked ELF exits 0                                       | ✅    |
| 1      | `ret i32 <imm>` for any 32-bit constant            | exit code matches lower 8 bits                           | ✅    |
| 2      | one i32 argument, cdecl                            | call from a synthesised `_start`                         | ✅    |
| 3      | i32 `add/sub/and/or/xor`, shift-imm                | execution tests (2-address chain coverage)               | ✅    |
| 3.5    | reg-shift (CL constraint), narrow-int promotion    | execution tests (i8/i16 wrap-around)                     | ✅    |
| 4      | `alloca/load/store` + EBP frame + real spill       | exec: `rmw` + `spill_chain` + `use_alloca`               | ✅    |
| 5      | `icmp + br` (CMP + Jcc 10 predicates)              | execution: `is_42` / `is_not_42` / `min` / `abs` / `is_lt_unsigned` | ✅ |
| 6a     | direct cdecl `call` between user-defined functions | exec: `call_identity`, `call_add2`, `call_live_across`   | ✅    |
| 6.5    | `examples/rust` (cargo → IR → llvm-mov-llc → ELF)  | `make test-rust-example` — `rust_main` + `fib_main`      | ✅    |
| 7a     | ADD32 rr/ri mov-only via byte-add carry-chain table | `test/MovOnly/add42` + `add_rr` pass the objdump gate   | ✅    |
| 7b1    | AND / OR / XOR rr/ri mov-only                      | bitwise objdump fixtures pass                            | ✅    |
| 7b2    | SHL / SHR / SAR ri mov-only                        | shift-imm fixtures pass                                  | ✅    |
| 7b3    | SHL / SHR / SAR rCL mov-only (5-stage unroll)      | variable-shift fixtures pass                             | ✅    |
| 7c1    | CFG → branchless dispatcher                        | every BB ends with `mov [next_pc]; jmp dispatcher`        | ✅    |
| 7c2    | CMP + Jcc(E/NE) mov-only                           | `is_42`, `eq42` lose all `cmp`/`je`/`jne`                | ✅    |
| 7c3    | CMP + Jcc(B/AE/BE/A) (unsigned) mov-only           | `is_lt_unsigned`, `lt_unsigned`                          | ✅    |
| 7c4    | CMP + Jcc(L/GE/LE/G) (signed) mov-only             | `smin`, `is_lt_signed`, `sum10`'s `jl` loop bound        | ✅    |
| 7d0    | `SUB32ri` incl. prologue `sub esp, K` mov-only     | bench's `sub` column drops out                           | ✅    |
| 7d1    | `pop ebp + ret` via `__mov_return_addr_slot`       | bench's `pop` / `ret` columns drop                       | ✅    |
| 7d2    | prologue `push ebp` via `__mov_esp_dec_scratch`    | bench's `push` column drops                              | ✅    |
| 7d3    | `CALL32d` → MBB-split + `JMP32d_CALL`              | `call_*` fixtures gate green                             | ✅    |
| 7e     | CTPOP / CTLZ / CTTZ via 256-entry byte tables      | `test/MovOnly/{popcount,ctlz,cttz}` gate green           | ✅    |
| 7f1    | 32-bit MUL via byte-pair schoolbook + add chain    | `mul` / `mul_ri` / `mul_wide` fixtures green             | ✅    |
| 7f2    | 32-bit UDIV / SDIV / UREM / SREM via `__udivsi3` etc. injected by `llvm-mov-llc` as IR (restoring 32-iter division) | `udiv` / `sdiv` / `urem` / `srem` + `udiv` / `srem` MovOnly gates green | ✅ |
| 7g1    | `f32 fadd / fsub / fcmp / sitofp / fptosi (+ unsigned)` via SDAG soft-float → `__addsf3 / __subsf3 / __{eq,ne,lt,le,gt,ge,unord}sf2 / __floatsisf / __fixsfsi` injected as IR | exec: `fadd_*`, `fsub_*`, `fcmp_*`, `sitofp`, `fptosi`, `round_trip`; MovOnly: `fadd`, `fsub`, `fcmp`, `sitofp`, `fptosi` | ✅ |
| 7g2    | `f32 fmul` via SDAG soft-float → `__mulsf3` injected as IR (24×24→48-bit byte-split multiply on top of stage-7f1 `mul i32`) | exec: `fmul_*`; MovOnly: `fmul` | ✅ |
| 7g3    | `f32 fdiv` via SDAG soft-float → `__divsf3` injected as IR (23-iter mantissa restoring long-division loop with PHIs, same shape as stage-7f2 `__udivsi3`) | exec: `fdiv_*`; MovOnly: `fdiv` | ✅ |
| 7g4    | Inf / NaN propagation for fadd / fmul / fdiv (`fsub` inherits via `__subsf3 → __addsf3`). Canonical qNaN (0x7FC00000) for NaN inputs and IEEE-indeterminate cases (`Inf − Inf`, `0 × Inf`, `Inf / Inf`, `0 / 0`); signed Inf preserved for `Inf + finite`, `Inf × finite`, `Inf / finite`; signed zero for `finite / Inf` | exec: `fadd_{nan,inf_inf,inf_neg_inf,finite_inf}`, `fmul_{nan,zero_inf,inf_finite,inf_inf}`, `fdiv_{nan,inf_inf,inf_finite,finite_inf}` | ✅ |
| 7h1    | f32 ↔ f64 conversions via `__extendsfdf2` / `__truncdfsf2` injected as IR. First beachhead for f64; arithmetic helpers and f32↔f64 cmp / conversions land separately. Also: i64 `select` joins i32 in the SELECT→bit-blend rewrite (otherwise default Expand pins DAG-ISel on the helper bodies), and `legalizeRetEpilogueTail` now preserves caller-EDX so EDX:EAX multi-value returns (i64, `(usize, usize)`, …) survive the mov-only `pop ebp+ret` rewrite. | exec: `f64_roundtrip`, `f64_extend{,_inf,_nan,_neg,_zero}`, `f64_trunc_{inf,nan,neg}`; MovOnly: `f64_extend`, `f64_trunc` | ✅ |
| 6e     | indirect `call` via function pointer (CALL32r)     | `indirect_call` exec + MovOnly                           | ✅    |
| 8      | bigger fixtures (AES, mandelbrot, …)               | richer side-by-side bench                                | future |

At stage 0–6 the emitter is "mov-heavy" — `jmp/call/ret/cmp` were
still allowed. Stage 7 (the `MovOnlyLegalize` `MachineFunctionPass`)
rewrites every one into a mov-only byte-table chain. Splitting the
two phases is intentional: it lets the compiler skeleton stabilise
before the mov-only constraint dominates every decision.

The mov-only legalize is followed by six rounds of per-site
optimisation (`opt 1`..`opt 6`) which together shave 5–16 % off the
post-stage-7d byte-chain sites without changing semantics — see the
[`bench/results.md`](bench/results.md) commit history for the
fixture-by-fixture impact of each.

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
    rust/main/           cargo + rustc → llvm-mov-llc → ELF (`rust_main` → 42)
    rust/fib/            cargo + rustc → llvm-mov-llc → ELF (`fib_main` → 32, fib(24))
  bench/                 side-by-side vs movfuscator + clang/rustc -O0..-O3
  CLAUDE.md              meta dev guidance (TDD, gate matrix, dep pins)
  DESIGN.md              architecture / staged plan
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

The third signal is the **mov-only gate**: parse
`build/bin/llvm-mov-llc` output with `objdump -d -Mintel` and assert no
instruction other than `mov` (with each fixture's `.expect` whitelist for
opcodes that remain pending a future stage) appears in `.text`. After
stage 7d the `.expect` files have shrunk to a single line — `jmp` (the
dispatcher / call-continuation indirect branch, gate-accepted as
mov-equivalent). The gate runs in CI via `make test-mov-only`.

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
