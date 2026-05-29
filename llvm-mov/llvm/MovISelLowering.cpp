//===-- MovISelLowering.cpp -----------------------------------------------===//
//
// Stage-0 lowering: no formal arguments handled, return values handled for
// i32 only (CCAssignToReg<[EAX]> via RetCC_Mov). Calls aren't lowered yet —
// they'll come in stage 6.
//
//===----------------------------------------------------------------------===//

#include "MovISelLowering.h"
#include "MCTargetDesc/MovMCTargetDesc.h"
#include "MovSubtarget.h"
#include "llvm/CodeGen/CallingConvLower.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/SelectionDAG.h"
#include "llvm/CodeGen/TargetLoweringObjectFileImpl.h"
#include "llvm/IR/DiagnosticInfo.h"
#include "llvm/Support/ErrorHandling.h"

using namespace llvm;

// TableGen-generated calling-conv dispatchers (CC_Mov, RetCC_Mov).
#include "MovGenCallingConv.inc"

MovTargetLowering::MovTargetLowering(const TargetMachine &TM,
                                     const MovSubtarget &STI)
    : TargetLowering(TM, STI) {
  addRegisterClass(MVT::i32, &Mov::GPR32RegClass);
  // Stage 7g0 — f32 is intentionally NOT given a register class. The
  // type legalizer sees f32 as illegal and soft-promotes it to i32
  // before ISel runs: every fadd/fsub/etc. SDAG node becomes a libcall
  // taking i32 bit-patterns. The compiler-rt-named helpers
  // (`__addsf3`, etc.) are injected as IR by `llvm-mov-llc` (stage 7g1
  // — see the helper definitions in tools/llvm-mov-llc/main.cpp).
  // This is the standard soft-float lowering pattern other backends
  // (RISC-V soft-float, MSP430, …) use and keeps every TableGen
  // pattern operating purely on i32.
  computeRegisterProperties(STI.getRegisterInfo());

  setStackPointerRegisterToSaveRestore(Mov::ESP);
  setBooleanContents(ZeroOrOneBooleanContent);

  // Narrow ext-load policy.
  //
  // i8 ZEXTLOAD/EXTLOAD/SEXTLOAD are Custom — see LowerExtLoadI8 below.
  // Each lowers in the SDAG to an aligned-down 4-byte load plus a
  // shift-and-mask sequence, so the backend never has to synthesise
  // GR8 vregs for byte-stream reads (an earlier attempt at GR8-based
  // patterns tripped the post-isel scheduler — codex review on
  // 825044a). The aligned-down read is always within the enclosing
  // i32 word of the original i8 pointer, so it can never page-fault
  // past the surrounding object. SEXTLOAD adds a `(x << 24) >>a 24`
  // tail to sign-extend the extracted byte to i32.
  //
  // i16 / i1 stays Expand for now: rare in Rust IR, and adding the
  // same Custom path is mechanical when the time comes.
  setLoadExtAction(ISD::EXTLOAD,  MVT::i32, MVT::i8, Custom);
  setLoadExtAction(ISD::ZEXTLOAD, MVT::i32, MVT::i8, Custom);
  setLoadExtAction(ISD::SEXTLOAD, MVT::i32, MVT::i8, Custom);
  for (MVT MemVT : {MVT::i1, MVT::i16}) {
    setLoadExtAction(ISD::EXTLOAD,  MVT::i32, MemVT, Expand);
    setLoadExtAction(ISD::ZEXTLOAD, MVT::i32, MemVT, Expand);
    setLoadExtAction(ISD::SEXTLOAD, MVT::i32, MemVT, Expand);
  }

  // Stage 6d3b — truncating stores. `store i8` (trunc-from-i32 in IR)
  // lowers in LowerTruncStoreI8 to a read-modify-write on the
  // enclosing i32 word. Same alignment-safety story as the load
  // path: writing the aligned-down i32 word means we never touch
  // bytes outside the original object.
  setTruncStoreAction(MVT::i32, MVT::i8, Custom);
  setTruncStoreAction(MVT::i32, MVT::i16, Expand);
  setTruncStoreAction(MVT::i32, MVT::i1,  Expand);

  // x86 normally lowers `sign_extend_inreg` to `movsx`, which we don't
  // have. Without an action, signed narrow consumers — `sext i8 to i32`,
  // `signext i8` returns, `ashr i8` — would crash with "Cannot select
  // sign_extend_inreg" the moment stage 3.5 enabled narrow ABI values.
  // Expand lets the legalizer rewrite the node into the standard
  // `shl-N; sar-N` pair (which our SHL32ri/SAR32ri already cover) and
  // keeps the mov-heavy ISA honest about not having movsx.
  setOperationAction(ISD::SIGN_EXTEND_INREG, MVT::i1, Expand);
  setOperationAction(ISD::SIGN_EXTEND_INREG, MVT::i8, Expand);
  setOperationAction(ISD::SIGN_EXTEND_INREG, MVT::i16, Expand);

  // Stage 5: fold (BRCOND (SETCC a, b, cc) bb) into MovISD::BR_CC so the
  // selector can emit a glued CMP + Jcc pair. SETCC on its own (without
  // a BRCOND consumer — e.g. `select` or `zext i1`) isn't supported yet;
  // that's stage 5.5.
  //
  // We mark BOTH BRCOND and BR_CC Custom because the DAG legalizer
  // sometimes rewrites BRCOND(SETCC(...)) into BR_CC before our hook
  // gets a turn (especially when SETCC.i32 is Expand). Hooking both
  // sides means either shape ends up in MovISD::BR_CC.
  setOperationAction(ISD::BRCOND, MVT::Other, Custom);
  setOperationAction(ISD::BR_CC,  MVT::i32,   Custom);
  // SETCC i32 — Custom-lowered. The default Expand path eventually
  // calls SELECT_CC → BR_CC → SETCC again on certain shapes (the
  // legalizer iterates trying to find a target-acceptable form),
  // which loops forever in this backend because BR_CC is Custom
  // and SELECT_CC is Expand but they're effectively mutually
  // recursive. Lowering manually here breaks the cycle: we
  // emit pure SUB / XOR / LSHR / SRL combinations that produce
  // the 0/1 ZeroOrOneBooleanContent result the legalizer expects.
  setOperationAction(ISD::SETCC,  MVT::i32,   Custom);
  // Note: no Custom action for SIGN_EXTEND / ZERO_EXTEND / ANY_EXTEND.
  // The IR-rewrite pass in tools/llvm-mov-llc/main.cpp materialises
  // all branchless 0/1 → 0/-1 masks via `(0 - zext)` rather than
  // emitting `sext i1`, so an SDAG SIGN_EXTEND of a SETCC result
  // never reaches the legalizer here. Leaving these to their
  // defaults keeps the legalizer's i1-promotion path in charge.

  // No CMOVcc — Expand SELECT / SELECT_CC into the standard
  // branch + PHI shape (BRCOND target_bb, fallthrough). The
  // resulting BRCOND/BR_CC pair flows back through our existing
  // Custom hook above, so a `select` IR node ends up as a CMP +
  // Jcc + branch sequence (eventually mov-only-legalized by 7c2).
  setOperationAction(ISD::SELECT,    MVT::i32, Expand);
  setOperationAction(ISD::SELECT_CC, MVT::i32, Expand);

  // Stage 7i — jump tables for dense `switch` (issue #11). LLVM
  // forms a jump table whenever `areJTsAllowed()` holds, which is
  // true here because BRIND is Legal by default and `(brind GPR32)`
  // selects to our JMP32r. The catch: BR_JT also defaults to Legal,
  // so the jump-table branch reaches ISel un-expanded and aborts
  // with "Cannot select: br_jt" (the base64 / qoi deps hit exactly
  // this inside their error enums' `Display::fmt`). Marking BR_JT
  // Expand makes the DAG legalizer rewrite it into the portable
  //     index*4 -> +jumptable_base -> load -> brind
  // shape: the address arithmetic (SHL/ADD) and the load all go
  // through the existing i32 selection + stage-7 byte-chain
  // legalize, and only the trailing `brind` needs a target opcode
  // (JMP32r). The jump-table data itself (one absolute MBB address
  // per arm, EK_BlockAddress) is emitted by the base AsmPrinter's
  // emitJumpTableInfo; ISel materialises the table base via an
  // ISD::JumpTable -> MOV32ri in MovISelDAGToDAG.
  setOperationAction(ISD::BR_JT, MVT::Other, Expand);

  // No ROL/ROR opcode and no movfuscator-style rotate trick yet.
  // DAGCombine eagerly folds `(x << k) | (x >> (32-k))` into an
  // `ISD::ROTL` node; without an Expand action that would survive
  // as a "Cannot select: rotl" at ISel time. Marking it Expand
  // tells the legalizer to leave the shift+or pair alone (or to
  // re-expand back into one), which selects against our existing
  // SHL32ri / SHR32ri / OR32rr patterns. ROTR is handled the
  // same way for symmetry.
  setOperationAction(ISD::ROTL, MVT::i32, Expand);
  setOperationAction(ISD::ROTR, MVT::i32, Expand);

  // Stage 7f — 32-bit MUL has a dedicated MUL32{rr,ri} pseudo +
  // byte-table lowering in MovOnlyLegalize. The TableGen patterns
  // match `(mul …)` directly; this `Legal` action stops the
  // legalizer from synthesising a `__mulsi3` libcall (the previous
  // Expand path needed Rust user-crate stubs for the libcall to
  // resolve at link time — they're no longer required).
  setOperationAction(ISD::MUL, MVT::i32, Legal);
  // No 64-bit-result multiply either. UMUL_LOHI / SMUL_LOHI / MULH*
  // arise from i32 multiplications whose high half escapes (hashing,
  // 32x32→64 fixed-point, the modulo-by-constant fast path that
  // LLVM emits in place of an actual UDIV). Expand spells them as
  // narrow MUL + manual carry, which then re-expands via the MUL
  // Expand above into a libcall. The libcall still doesn't link
  // (no compiler-rt) but it stops crashing in ISel; runtime
  // multiplication is genuinely future-work for this backend.
  setOperationAction(ISD::UMUL_LOHI, MVT::i32, Expand);
  setOperationAction(ISD::SMUL_LOHI, MVT::i32, Expand);
  setOperationAction(ISD::MULHU,     MVT::i32, Expand);
  setOperationAction(ISD::MULHS,     MVT::i32, Expand);
  // DIV / REM round out the "we don't have a 32-bit multiplier"
  // story — same Expand→libcall path. Real code that wants these
  // must wait until the byte-chain mul/div stage lands.
  setOperationAction(ISD::UDIV, MVT::i32, Expand);
  setOperationAction(ISD::SDIV, MVT::i32, Expand);
  setOperationAction(ISD::UREM, MVT::i32, Expand);
  setOperationAction(ISD::SREM, MVT::i32, Expand);
  setOperationAction(ISD::UDIVREM, MVT::i32, Expand);
  setOperationAction(ISD::SDIVREM, MVT::i32, Expand);

  // Min / max / abs intrinsics. No CMOV-equivalent so each expands
  // into a CMP + Jcc + branch + PHI sequence (which the existing
  // 7c2 mov-only CMP+Jcc legalize then turns into a mov-only
  // dispatcher mask). Same Expand pattern as SELECT above —
  // arrives via DAGCombine from `core::cmp::min / max / Ord` and
  // from `llvm.abs.i32` / `llvm.umin.i32` etc. intrinsics in opt'd
  // Rust crates (qoi's index hash uses umin).
  for (auto Op : {ISD::SMIN, ISD::SMAX, ISD::UMIN, ISD::UMAX, ISD::ABS})
    setOperationAction(Op, MVT::i32, Expand);

  // Register the compiler-rt libcall names for the multiply/divide
  // family. The Expand actions above synthesise calls to these
  // symbols at SDAG time; without the explicit binding the
  // legalizer errors out with "no libcall available for mul". The
  // actual implementations are provided as small shift-and-add
  // Rust stubs in the example crates that need them
  // (examples/rust/qoi_decode/src/lib.rs etc.); when a future
  // stage adds a real byte-chain MUL legalize, these can move
  // back to MovOnlyLegalize and the libcall fall back goes away.
  setLibcallImpl(RTLIB::MUL_I32,   RTLIB::impl___mulsi3);
  setLibcallImpl(RTLIB::UDIV_I32,  RTLIB::impl___udivsi3);
  setLibcallImpl(RTLIB::SDIV_I32,  RTLIB::impl___divsi3);
  setLibcallImpl(RTLIB::UREM_I32,  RTLIB::impl___umodsi3);
  setLibcallImpl(RTLIB::SREM_I32,  RTLIB::impl___modsi3);

  // Stage 7g1 / 7g2 / 7g3 — single-precision floating-point ops. No
  // FPU exists in mov-only land, so every FP op routes through
  // compiler-rt-named libcalls. The action mark below is LibCall so
  // that the SDAG legalizer emits `call __<op>sf3` without trying to
  // find a native FP instruction first.
  setOperationAction(ISD::FADD, MVT::f32, LibCall);
  setOperationAction(ISD::FSUB, MVT::f32, LibCall);
  setOperationAction(ISD::FMUL, MVT::f32, LibCall);
  setOperationAction(ISD::FDIV, MVT::f32, LibCall);
  setLibcallImpl(RTLIB::ADD_F32, RTLIB::impl___addsf3);
  setLibcallImpl(RTLIB::SUB_F32, RTLIB::impl___subsf3);
  setLibcallImpl(RTLIB::MUL_F32, RTLIB::impl___mulsf3);
  setLibcallImpl(RTLIB::DIV_F32, RTLIB::impl___divsf3);

  // FP comparisons. Each predicate routes to its compiler-rt-named
  // helper; the helper bodies share a single underlying compare and
  // dispatch on the NaN-return convention. Driver injection sets up
  // the bodies so SDAG's f32 SETCC legalizer can issue these as
  // plain C-call libcalls and interpret the i32 result as the
  // three-way ordered compare (-1 / 0 / +1).
  setLibcallImpl(RTLIB::OEQ_F32, RTLIB::impl___eqsf2);
  setLibcallImpl(RTLIB::UNE_F32, RTLIB::impl___nesf2);
  setLibcallImpl(RTLIB::OLT_F32, RTLIB::impl___ltsf2);
  setLibcallImpl(RTLIB::OLE_F32, RTLIB::impl___lesf2);
  setLibcallImpl(RTLIB::OGT_F32, RTLIB::impl___gtsf2);
  setLibcallImpl(RTLIB::OGE_F32, RTLIB::impl___gesf2);
  setLibcallImpl(RTLIB::UO_F32,  RTLIB::impl___unordsf2);

  // i32 ⇄ f32 conversions. Same shape — the libcalls are bound to
  // compiler-rt names; the helper bodies are injected by the driver.
  setLibcallImpl(RTLIB::SINTTOFP_I32_F32, RTLIB::impl___floatsisf);
  setLibcallImpl(RTLIB::UINTTOFP_I32_F32, RTLIB::impl___floatunsisf);
  setLibcallImpl(RTLIB::FPTOSINT_F32_I32, RTLIB::impl___fixsfsi);
  setLibcallImpl(RTLIB::FPTOUINT_F32_I32, RTLIB::impl___fixunssfsi);

  // Stage 7h1 — first beachhead for f64. No FPU, and f64 has no
  // register class (same minimal-plumbing stance as f32 in 7g0), so
  // SDAG soft-float legalizes f64 nodes through libcalls into i64,
  // and then auto-expands i64 ops to i32-pair sequences. The only
  // f64 ops wired this round are the f32 ↔ f64 conversions — they're
  // the necessary entrypoint for any subsequent f64 arithmetic (the
  // user only sees f64 through `fpext` / `fptrunc` until those land)
  // and the helper bodies don't need variable-amount i64 shifts, so
  // they fit inside the current backend without a runtime i64 shift
  // libcall infra.
  setOperationAction(ISD::FP_EXTEND, MVT::f64, LibCall);
  setOperationAction(ISD::FP_ROUND,  MVT::f32, LibCall);
  setLibcallImpl(RTLIB::FPEXT_F32_F64,  RTLIB::impl___extendsfdf2);
  setLibcallImpl(RTLIB::FPROUND_F64_F32, RTLIB::impl___truncdfsf2);

  // Stage 7h2 — f64 fcmp. Same shape as f32 (each predicate routes
  // through its compiler-rt-named helper; the bodies share a single
  // three-way compare parameterised by the unord-return convention).
  // No setOperationAction needed — SDAG's f64 SETCC legalizer
  // already issues these as libcalls once the bindings are in place.
  setLibcallImpl(RTLIB::OEQ_F64, RTLIB::impl___eqdf2);
  setLibcallImpl(RTLIB::UNE_F64, RTLIB::impl___nedf2);
  setLibcallImpl(RTLIB::OLT_F64, RTLIB::impl___ltdf2);
  setLibcallImpl(RTLIB::OLE_F64, RTLIB::impl___ledf2);
  setLibcallImpl(RTLIB::OGT_F64, RTLIB::impl___gtdf2);
  setLibcallImpl(RTLIB::OGE_F64, RTLIB::impl___gedf2);
  setLibcallImpl(RTLIB::UO_F64,  RTLIB::impl___unorddf2);

  // Stage 7h3 — i32 ↔ f64 conversions. Same shape as the 7g1 f32
  // versions; helper bodies injected by the driver.
  setLibcallImpl(RTLIB::SINTTOFP_I32_F64, RTLIB::impl___floatsidf);
  setLibcallImpl(RTLIB::UINTTOFP_I32_F64, RTLIB::impl___floatunsidf);
  setLibcallImpl(RTLIB::FPTOSINT_F64_I32, RTLIB::impl___fixdfsi);
  setLibcallImpl(RTLIB::FPTOUINT_F64_I32, RTLIB::impl___fixunsdfsi);

  // Stage 7h4 / 7h5 / 7h6 — f64 fadd / fsub / fmul / fdiv. Helper
  // bodies emulate variable-amount i64 shifts via the i32-pair
  // clamped-arm split technique established by stage-7h3's
  // `__floatsidf` / `__fixdfsi`. fmul layers a 53×53 → 106-bit
  // mantissa multiply via four 32×32 sub-multiplies on top; fdiv
  // is a 52-iter restoring long-division loop on i64 values (same
  // shape as stage-7g3 `__divsf3`).
  setOperationAction(ISD::FADD, MVT::f64, LibCall);
  setOperationAction(ISD::FSUB, MVT::f64, LibCall);
  setOperationAction(ISD::FMUL, MVT::f64, LibCall);
  setOperationAction(ISD::FDIV, MVT::f64, LibCall);
  setLibcallImpl(RTLIB::ADD_F64, RTLIB::impl___adddf3);
  setLibcallImpl(RTLIB::SUB_F64, RTLIB::impl___subdf3);
  setLibcallImpl(RTLIB::MUL_F64, RTLIB::impl___muldf3);
  setLibcallImpl(RTLIB::DIV_F64, RTLIB::impl___divdf3);

  // No `bswap` opcode either. Rust idioms like `u32::from_be(x)` or
  // `x.swap_bytes()` lower to ISD::BSWAP. Expand re-spells it as
  // the standard four-byte shuffle (`(x << 24) | ((x & 0xff00) << 8)
  // | ((x >> 8) & 0xff00) | (x >> 24)`), which our SHL32ri /
  // SHR32ri / OR32rr / AND32ri patterns handle and the byte-chain
  // mov-only legalize at stage 7 lowers further. Same shape as the
  // hand-spelled `bswap32` in examples/rust/bmp_decode but applied
  // automatically to any IR that arrives with a real ISD::BSWAP.
  setOperationAction(ISD::BSWAP, MVT::i32, Expand);

  // Bit-count intrinsics (count leading zeros, count trailing zeros,
  // popcount, parity). No `bsf` / `bsr` / `popcnt` in mov-only land.
  //
  // Stage 7e — CTPOP / CTLZ / CTTZ each get a dedicated codegen-only
  // pseudo + byte-table lowering in MovOnlyLegalize. The TableGen
  // patterns on the pseudos match the SDAG nodes directly; this
  // `Legal` action lets DAG-ISel dispatch to them instead of
  // synthesising the SWAR Hamming-weight (CTPOP) / Hacker's Delight
  // population-of-(x | x>>1 | … | x>>16) (CTLZ/CTTZ) expansions.
  //
  // The CTPOP Expand left a `sub eax, ecx` un-lowered and bloated
  // `.text` by ~4×; the CTLZ/CTTZ Expand stayed mov-only but came
  // in at ~600 movs per site (the shift-chain expansion uses 8+
  // 32-bit ops, each of which becomes a ~50-mov byte chain). Byte-
  // table lowering brings CTLZ/CTTZ down to ~150 movs per site.
  //
  // CTLZ_ZERO_UNDEF / CTTZ_ZERO_UNDEF target the same pseudos via
  // `Pat<>` rules in MovInstrInfo.td — the byte-table lowering
  // returns the defined value 32 for x=0, which is a valid result
  // for both the regular and ZERO_UNDEF variants.
  for (auto Op : {ISD::CTPOP, ISD::CTLZ, ISD::CTLZ_ZERO_UNDEF,
                  ISD::CTTZ, ISD::CTTZ_ZERO_UNDEF})
    setOperationAction(Op, MVT::i32, Legal);

  // Stage 6c — inline llvm.memset / llvm.memcpy / llvm.memmove
  // rather than emitting libcalls. Our standalone runtime doesn't
  // link libc, and SelectionDAG's fallback is to call
  // memset/memcpy/memmove which would crash at link time. Raising
  // the per-call store budget high enough that constant-size
  // intrinsics fall into the inline expansion. The cap of 64 covers
  // the common Rust crate sizes (16/32-byte block fills, 96-byte
  // struct copies) without bloating tiny memcpys.
  MaxStoresPerMemset  = MaxStoresPerMemsetOptSize  = 64;
  MaxStoresPerMemcpy  = MaxStoresPerMemcpyOptSize  = 64;
  MaxStoresPerMemmove = MaxStoresPerMemmoveOptSize = 64;
}

SDValue MovTargetLowering::LowerOperation(SDValue Op, SelectionDAG &DAG) const {
  switch (Op.getOpcode()) {
  case ISD::BRCOND:
    return LowerBRCOND(Op, DAG);
  case ISD::BR_CC:
    return LowerBR_CC(Op, DAG);
  case ISD::LOAD:
    return LowerExtLoadI8(Op, DAG);
  case ISD::STORE:
    return LowerTruncStoreI8(Op, DAG);
  case ISD::SETCC:
    return LowerSETCC(Op, DAG);
  default:
    llvm_unreachable("Mov: LowerOperation called on unhandled opcode");
  }
}

SDValue MovTargetLowering::LowerSETCC(SDValue Op, SelectionDAG &DAG) const {
  // Stage 6d3e — Custom-lower `setcc i32` to a branchless integer
  // expression that produces 0/1 (matching `ZeroOrOneBooleanContent`).
  // The default Expand path generates SELECT_CC, which the legalizer
  // would expand again via BR_CC → SETCC → SELECT_CC ... — a loop
  // that hangs DAG-ISel indefinitely on a fixture as small as
  // `define i1 @f(i32, i32) { %c = icmp uge i32 ...; ret i1 %c }`.
  //
  // Per-predicate primitives, all bottoming out in SUB / XOR / OR /
  // AND / SRL (no signed shift, no overflow-sensitive arithmetic):
  //
  //   SLT(a, b) — Hacker's Delight 2.12 "overflow-safe sign of
  //               difference". `((a-b) ^ ((a^b) & ((a-b) ^ a))) >> 31`
  //               is true (1) iff a < b in signed arithmetic, even
  //               when a-b overflows. Verified against
  //               a = INT_MIN, b = 1 (true) and
  //               a = INT_MAX, b = -1 (false).
  //
  //   ULT(a, b) — bias both by 0x80000000 (XOR), then SLT. After the
  //               bias unsigned ordering becomes signed ordering on
  //               the same bit pattern; the safe SLT then handles
  //               it without overflow.
  //
  //   EQ(a, b)  — `((x|-x) >> 31) == 0` where x = a^b. NE inverts.
  //
  // All other predicates derive from these via not / swap of
  // operands.
  SDLoc DL(Op);
  SDValue LHS = Op.getOperand(0);
  SDValue RHS = Op.getOperand(1);
  ISD::CondCode CC = cast<CondCodeSDNode>(Op.getOperand(2))->get();
  EVT VT = Op.getValueType();

  // `(x >> 31)` via SRL — 1 iff x has its top bit set, 0 otherwise.
  // Using SRL (not SRA) keeps the result in the 0/1 boolean domain.
  auto SignBit = [&](SDValue X) {
    return DAG.getNode(ISD::SRL, DL, MVT::i32, X,
                       DAG.getConstant(31, DL, MVT::i32));
  };
  // Signed less-than (overflow-safe).
  auto Slt = [&](SDValue A, SDValue B) {
    SDValue Sub = DAG.getNode(ISD::SUB, DL, MVT::i32, A, B);
    SDValue Xab = DAG.getNode(ISD::XOR, DL, MVT::i32, A, B);
    SDValue Xsa = DAG.getNode(ISD::XOR, DL, MVT::i32, Sub, A);
    SDValue And = DAG.getNode(ISD::AND, DL, MVT::i32, Xab, Xsa);
    SDValue Mix = DAG.getNode(ISD::XOR, DL, MVT::i32, Sub, And);
    return SignBit(Mix);
  };
  // Unsigned less-than via bias + signed compare.
  auto Ult = [&](SDValue A, SDValue B) {
    SDValue M  = DAG.getConstant(0x80000000u, DL, MVT::i32);
    SDValue Ap = DAG.getNode(ISD::XOR, DL, MVT::i32, A, M);
    SDValue Bp = DAG.getNode(ISD::XOR, DL, MVT::i32, B, M);
    return Slt(Ap, Bp);
  };
  // (x | -x) has its sign bit set iff x != 0.
  auto NeZ = [&](SDValue X) {
    SDValue Neg = DAG.getNode(ISD::SUB, DL, MVT::i32,
                              DAG.getConstant(0, DL, MVT::i32), X);
    SDValue Or  = DAG.getNode(ISD::OR, DL, MVT::i32, X, Neg);
    return SignBit(Or);
  };
  auto Eq = [&](SDValue A, SDValue B) {
    SDValue Xor = DAG.getNode(ISD::XOR, DL, MVT::i32, A, B);
    SDValue Nez = NeZ(Xor);
    return DAG.getNode(ISD::XOR, DL, MVT::i32, Nez,
                       DAG.getConstant(1, DL, MVT::i32));
  };
  auto Not = [&](SDValue X) {
    return DAG.getNode(ISD::XOR, DL, MVT::i32, X,
                       DAG.getConstant(1, DL, MVT::i32));
  };

  SDValue R;
  switch (CC) {
  case ISD::SETLT:  R = Slt(LHS, RHS);            break;
  case ISD::SETGT:  R = Slt(RHS, LHS);            break;
  case ISD::SETLE:  R = Not(Slt(RHS, LHS));       break;
  case ISD::SETGE:  R = Not(Slt(LHS, RHS));       break;
  case ISD::SETULT: R = Ult(LHS, RHS);            break;
  case ISD::SETUGT: R = Ult(RHS, LHS);            break;
  case ISD::SETULE: R = Not(Ult(RHS, LHS));       break;
  case ISD::SETUGE: R = Not(Ult(LHS, RHS));       break;
  case ISD::SETEQ:  R = Eq(LHS, RHS);             break;
  case ISD::SETNE:  R = Not(Eq(LHS, RHS));        break;
  default:
    report_fatal_error("Mov: unsupported SETCC predicate");
  }
  // R is i32 0/1; if the SDAG node wants a narrower type, truncate.
  if (VT != MVT::i32)
    R = DAG.getNode(ISD::TRUNCATE, DL, VT, R);
  return R;
}

SDValue MovTargetLowering::LowerExtLoadI8(SDValue Op, SelectionDAG &DAG) const {
  // Stage 6d3b — custom expansion of (ext)load (s8) into a single
  // aligned-down 4-byte load + a shift+mask sequence:
  //
  //   aligned_ptr  = ptr & ~3
  //   byte_off     = ptr &  3                ; 0..3
  //   bit_shift    = byte_off << 3            ; 0, 8, 16, or 24
  //   word         = load i32, [aligned_ptr]  ; always within object
  //   raw_byte     = (word >> bit_shift) & 0xff
  //   result       = raw_byte                       (zext / anyext)
  //              or = (raw_byte << 24) >>a 24       (sext)
  //
  // The aligned-down read trick is what keeps the lowering safe at
  // object boundaries: a byte at offset 13 of a 16-byte alloca
  // belongs to the i32 word at [12..16) which is always inside the
  // alloca. A naive read at the byte's address could step into the
  // next page if the byte happened to sit at a page boundary.
  //
  // The full op sequence (shift right by variable + mask + optional
  // sext shifts) is heavy for an 8-bit load, but it is what
  // "scalar-only mov-only" buys us: the byte-chain mov-only legalize
  // at stage 7 already handles every op in this expansion, and the
  // resulting `.text` stays mov-only without any GR8 plumbing.
  auto *LD = cast<LoadSDNode>(Op);
  if (LD->getMemoryVT() != MVT::i8)
    return SDValue(); // Only i8 ext-loads are custom-handled here.

  SDLoc DL(Op);
  SDValue Chain = LD->getChain();
  SDValue Ptr   = LD->getBasePtr();
  EVT PtrTy     = Ptr.getValueType();
  EVT ResTy     = Op.getValueType();

  // aligned_ptr = ptr & ~3, byte_off = ptr & 3.
  SDValue Three     = DAG.getConstant(3, DL, PtrTy);
  SDValue InvThree  = DAG.getConstant(~3u, DL, PtrTy);
  SDValue AlignedPt = DAG.getNode(ISD::AND, DL, PtrTy, Ptr, InvThree);
  SDValue ByteOff   = DAG.getNode(ISD::AND, DL, PtrTy, Ptr, Three);
  SDValue BitShift  = DAG.getNode(ISD::SHL, DL, PtrTy, ByteOff,
                                  DAG.getConstant(3, DL, PtrTy));

  // Word load. PointerInfo is conservative — the aligned-down ptr
  // still points into the same underlying object as the original
  // i8 pointer, so the original MMO's alias info applies.
  MachineMemOperand *MMO = LD->getMemOperand();
  SDValue Word = DAG.getLoad(MVT::i32, DL, Chain, AlignedPt,
                             MachinePointerInfo(MMO->getPointerInfo()),
                             Align(4), MMO->getFlags());

  // Extract the requested byte.
  SDValue Shifted = DAG.getNode(ISD::SRL, DL, MVT::i32, Word, BitShift);
  SDValue ByteVal = DAG.getNode(ISD::AND, DL, MVT::i32, Shifted,
                                DAG.getConstant(0xff, DL, MVT::i32));

  // For SEXTLOAD, sign-extend the byte from 8 to 32 bits via
  // `(x << 24) >>a 24`. Both shifts are by a compile-time constant
  // 24, so they select to SHL32ri / SAR32ri (and survive byte-chain).
  SDValue Result;
  if (LD->getExtensionType() == ISD::SEXTLOAD) {
    SDValue Sh = DAG.getConstant(24, DL, MVT::i32);
    SDValue Up = DAG.getNode(ISD::SHL, DL, MVT::i32, ByteVal, Sh);
    Result     = DAG.getNode(ISD::SRA, DL, MVT::i32, Up, Sh);
  } else {
    // EXTLOAD and ZEXTLOAD: the AND 0xff already produced a
    // zero-extended i32, which is exactly what the consumer wants.
    Result = ByteVal;
  }

  // Result type might be smaller than i32 if the consumer truncates
  // it later; for ZEXTLOAD / EXTLOAD the source ext is from i8 to
  // the natural promote type i32, so ResTy == i32 in practice.
  if (Result.getValueType() != ResTy)
    Result = DAG.getNode(ISD::TRUNCATE, DL, ResTy, Result);

  return DAG.getMergeValues({Result, Word.getValue(1)}, DL);
}

SDValue MovTargetLowering::LowerTruncStoreI8(SDValue Op, SelectionDAG &DAG) const {
  // Stage 6d3b — truncating store of i8 → read-modify-write on the
  // enclosing aligned i32 word:
  //
  //   aligned_ptr  = ptr & ~3
  //   byte_off     = ptr &  3
  //   bit_shift    = byte_off << 3
  //   word         = load  i32, [aligned_ptr]
  //   cleared      = word & ~(0xff << bit_shift)
  //   new_byte     = (val & 0xff) << bit_shift
  //   store i32 (cleared | new_byte), [aligned_ptr]
  //
  // Same alignment-safety argument as LowerExtLoadI8: the i32 word
  // we read+write straddles the original i8 byte, but always sits
  // inside the same underlying object, so we never page-fault past
  // its end. The op chain is heavy (load, two masks, two shifts,
  // OR, store) but every op is i32 and selects against the existing
  // MOV32rm / AND32ri / SHL32ri / OR32rr / MOV32mr patterns —
  // mov-only legalize at stage 7 picks them all up.
  auto *ST = cast<StoreSDNode>(Op);
  if (ST->getMemoryVT() != MVT::i8 || !ST->isTruncatingStore())
    return SDValue();

  SDLoc DL(Op);
  SDValue Chain = ST->getChain();
  SDValue Val   = ST->getValue();
  SDValue Ptr   = ST->getBasePtr();
  EVT PtrTy     = Ptr.getValueType();

  SDValue Three     = DAG.getConstant(3, DL, PtrTy);
  SDValue InvThree  = DAG.getConstant(~3u, DL, PtrTy);
  SDValue AlignedPt = DAG.getNode(ISD::AND, DL, PtrTy, Ptr, InvThree);
  SDValue ByteOff   = DAG.getNode(ISD::AND, DL, PtrTy, Ptr, Three);
  SDValue BitShift  = DAG.getNode(ISD::SHL, DL, PtrTy, ByteOff,
                                  DAG.getConstant(3, DL, PtrTy));

  // Two separate MachineMemOperands — the original store's MMO has
  // store flags set, but we now need a load-only MMO for the
  // pre-load and a store-only MMO for the back-store. Sharing the
  // original would have MOV32rm carrying a store-flagged MMO and
  // the verifier rejects it ("Missing mayStore flag").
  MachineFunction &MF = DAG.getMachineFunction();
  MachineMemOperand *OrigMMO = ST->getMemOperand();
  MachineMemOperand *LoadMMO = MF.getMachineMemOperand(
      OrigMMO->getPointerInfo(),
      MachineMemOperand::MOLoad,
      /*size=*/4, Align(4), OrigMMO->getAAInfo(),
      OrigMMO->getRanges(), OrigMMO->getSyncScopeID(),
      OrigMMO->getSuccessOrdering(), OrigMMO->getFailureOrdering());
  MachineMemOperand *StoreMMO = MF.getMachineMemOperand(
      OrigMMO->getPointerInfo(),
      MachineMemOperand::MOStore,
      /*size=*/4, Align(4), OrigMMO->getAAInfo(),
      OrigMMO->getRanges(), OrigMMO->getSyncScopeID(),
      OrigMMO->getSuccessOrdering(), OrigMMO->getFailureOrdering());

  SDValue Word = DAG.getLoad(MVT::i32, DL, Chain, AlignedPt, LoadMMO);

  // ~(0xff << bit_shift) — we have no NOT opcode, so XOR with ~0.
  SDValue ByteMask = DAG.getNode(ISD::SHL, DL, MVT::i32,
                                 DAG.getConstant(0xff, DL, MVT::i32),
                                 BitShift);
  SDValue AllOnes  = DAG.getConstant(0xFFFFFFFFu, DL, MVT::i32);
  SDValue InvMask  = DAG.getNode(ISD::XOR, DL, MVT::i32, ByteMask, AllOnes);
  SDValue Cleared  = DAG.getNode(ISD::AND, DL, MVT::i32, Word, InvMask);

  SDValue NewByte = DAG.getNode(ISD::AND, DL, MVT::i32, Val,
                                DAG.getConstant(0xff, DL, MVT::i32));
  SDValue Shifted = DAG.getNode(ISD::SHL, DL, MVT::i32, NewByte, BitShift);
  SDValue Merged  = DAG.getNode(ISD::OR, DL, MVT::i32, Cleared, Shifted);

  return DAG.getStore(Word.getValue(1), DL, Merged, AlignedPt, StoreMMO);
}

SDValue MovTargetLowering::LowerBRCOND(SDValue Op, SelectionDAG &DAG) const {
  // BRCOND operand layout: (chain, cond, target_bb)
  SDValue Chain  = Op.getOperand(0);
  SDValue Cond   = Op.getOperand(1);
  SDValue Target = Op.getOperand(2);
  SDLoc DL(Op);

  ISD::CondCode CC;
  SDValue LHS, RHS;
  if (Cond.getOpcode() == ISD::SETCC) {
    // The common case: `br i1 (icmp cc a, b)` lowers as
    // BRCOND(SETCC(a, b, cc), bb). Pull cc/a/b out and pack them into
    // MovISD::BR_CC so we can emit a single CMP + Jcc pair.
    LHS = Cond.getOperand(0);
    RHS = Cond.getOperand(1);
    CC  = cast<CondCodeSDNode>(Cond.getOperand(2))->get();
  } else {
    // `br i1 %v` where %v isn't a SETCC: branch when %v is non-zero.
    // We synthesize `CMP %v, 0; JNE` by lowering through BR_CC with
    // SETNE against a literal 0.
    LHS = Cond;
    RHS = DAG.getConstant(0, DL, MVT::i32);
    CC  = ISD::SETNE;
  }

  return DAG.getNode(MovISD::BR_CC, DL, MVT::Other, Chain,
                     DAG.getCondCode(CC), LHS, RHS, Target);
}

SDValue MovTargetLowering::LowerBR_CC(SDValue Op, SelectionDAG &DAG) const {
  // ISD::BR_CC operand layout: (chain, cc, lhs, rhs, target_bb).
  // Repack as MovISD::BR_CC; the selector emits CMP + Jcc.
  SDValue Chain  = Op.getOperand(0);
  SDValue CCNode = Op.getOperand(1);
  SDValue LHS    = Op.getOperand(2);
  SDValue RHS    = Op.getOperand(3);
  SDValue Target = Op.getOperand(4);
  SDLoc DL(Op);
  return DAG.getNode(MovISD::BR_CC, DL, MVT::Other,
                     Chain, CCNode, LHS, RHS, Target);
}

const char *MovTargetLowering::getTargetNodeName(unsigned Opcode) const {
  switch (Opcode) {
  case MovISD::RET:   return "MovISD::RET";
  case MovISD::BR_CC: return "MovISD::BR_CC";
  case MovISD::CALL:  return "MovISD::CALL";
  default:            return nullptr;
  }
}

SDValue MovTargetLowering::LowerFormalArguments(
    SDValue Chain, CallingConv::ID CallConv, bool /*IsVarArg*/,
    const SmallVectorImpl<ISD::InputArg> &Ins, const SDLoc &DL,
    SelectionDAG &DAG, SmallVectorImpl<SDValue> &InVals) const {
  MachineFunction &MF = DAG.getMachineFunction();
  MachineFrameInfo &MFI = MF.getFrameInfo();

  SmallVector<CCValAssign, 8> ArgLocs;
  CCState CCInfo(CallConv, /*IsVarArg=*/false, MF, ArgLocs,
                 *DAG.getContext());
  CCInfo.AnalyzeFormalArguments(Ins, CC_Mov);

  for (size_t i = 0; i < ArgLocs.size(); ++i) {
    CCValAssign &VA = ArgLocs[i];
    const ISD::ArgFlagsTy &Flags = Ins[i].Flags;
    if (!VA.isMemLoc()) {
      // Register-passed args land at stage 6 — until then CC_Mov assigns
      // everything to the stack, so a reg-loc here means the CC table and
      // this lowering have diverged.
      report_fatal_error("Mov: register-passed formal arg unexpected");
    }

    // Stage 6b — byval formal arg. The struct's bytes are at
    // [esp + 4 + locmem-offset]; the IR-level callee receives a
    // pointer to that location (a FrameIndex pointer, lowered to
    // [ebp + …] post-PEI). Allocate the FixedObject at the struct's
    // full size so PEI's stack-size computation accounts for it.
    if (Flags.isByVal()) {
      const unsigned Size = Flags.getByValSize();
      const int FI = MFI.CreateFixedObject(Size, 4 + VA.getLocMemOffset(),
                                           /*IsImmutable=*/false);
      SDValue FIN = DAG.getFrameIndex(FI, getPointerTy(DAG.getDataLayout()));
      InVals.push_back(FIN);
      continue;
    }

    // cdecl: each i32 (incl. promoted i1/i8/i16) arg occupies one 4-byte
    // stack slot. Right after `call`, callee's [esp+0] holds the return
    // address and [esp+4] holds arg0 — VA.getLocMemOffset() is the offset
    // *from arg0*, so the on-stack location of this arg is
    // (4 + LocMemOffset). eliminateFrameIndex resolves the FI to the
    // matching [esp + n] later (frame size is 0 at stage 2/3 so the
    // fixed-object offset translates 1:1).
    const unsigned Size = VA.getLocVT().getStoreSize();
    const int FI = MFI.CreateFixedObject(Size, 4 + VA.getLocMemOffset(),
                                         /*IsImmutable=*/true);

    SDValue FIN = DAG.getFrameIndex(FI, getPointerTy(DAG.getDataLayout()));
    SDValue Arg = DAG.getLoad(VA.getLocVT(), DL, Chain, FIN,
                              MachinePointerInfo::getFixedStack(MF, FI));

    // Stage 3.5: if CC_Mov promoted a narrow integer to i32, the load
    // returned an i32 but the IR-level consumer expects the original
    // narrow VT — TRUNCATE back so SelectionDAGBuilder's bookkeeping
    // lines up. (LocInfo distinguishes Full from {AExt, ZExt, SExt}; in
    // all three "Ext" cases the in-register value's low bits are the
    // payload, so a plain truncate is correct.)
    if (VA.getLocInfo() != CCValAssign::Full)
      Arg = DAG.getNode(ISD::TRUNCATE, DL, VA.getValVT(), Arg);
    InVals.push_back(Arg);
  }
  return Chain;
}

SDValue MovTargetLowering::LowerReturn(
    SDValue Chain, CallingConv::ID CallConv, bool /*IsVarArg*/,
    const SmallVectorImpl<ISD::OutputArg> &Outs,
    const SmallVectorImpl<SDValue> &OutVals, const SDLoc &DL,
    SelectionDAG &DAG) const {
  SmallVector<CCValAssign, 4> RVLocs;
  CCState CCInfo(CallConv, /*IsVarArg=*/false, DAG.getMachineFunction(), RVLocs,
                 *DAG.getContext());
  CCInfo.AnalyzeReturn(Outs, RetCC_Mov);

  SmallVector<SDValue, 4> RetOps;
  RetOps.push_back(Chain);

  SDValue Glue;
  for (unsigned i = 0, e = RVLocs.size(); i != e; ++i) {
    CCValAssign &VA = RVLocs[i];
    assert(VA.isRegLoc() && "stage 0 RetCC always assigns to a register");
    SDValue Val = OutVals[i];
    // Stage 3.5: narrow returns (i1/i8/i16) get promoted by RetCC_Mov to
    // i32 in EAX. The caller only looks at the low bits — `i8 add` of
    // 250+10 has to truncate-wrap to 4 — but we still need to widen
    // the value before CopyToReg because EAX is i32. ANY_EXTEND keeps
    // the high bits as don't-care, which is what the cdecl return
    // contract allows.
    switch (VA.getLocInfo()) {
    case CCValAssign::Full:
      break;
    case CCValAssign::AExt:
      Val = DAG.getNode(ISD::ANY_EXTEND, DL, VA.getLocVT(), Val);
      break;
    case CCValAssign::ZExt:
      Val = DAG.getNode(ISD::ZERO_EXTEND, DL, VA.getLocVT(), Val);
      break;
    case CCValAssign::SExt:
      Val = DAG.getNode(ISD::SIGN_EXTEND, DL, VA.getLocVT(), Val);
      break;
    default:
      report_fatal_error(Twine("Mov: unexpected CCValAssign::LocInfo=") +
                         Twine(static_cast<int>(VA.getLocInfo())) +
                         " in LowerReturn (ValVT=" +
                         Twine(VA.getValVT().SimpleTy) +
                         ", LocVT=" +
                         Twine(VA.getLocVT().SimpleTy) + ")");
    }
    Chain = DAG.getCopyToReg(Chain, DL, VA.getLocReg(), Val, Glue);
    Glue  = Chain.getValue(1);
    RetOps.push_back(DAG.getRegister(VA.getLocReg(), VA.getLocVT()));
  }

  if (Glue.getNode())
    RetOps.push_back(Glue);

  return DAG.getNode(MovISD::RET, DL, MVT::Other, RetOps);
}

//===----------------------------------------------------------------------===//
// LowerCall — stage 6a, cdecl, direct, scalar-only.
//===----------------------------------------------------------------------===//

SDValue MovTargetLowering::LowerCall(CallLoweringInfo &CLI,
                                     SmallVectorImpl<SDValue> &InVals) const {
  SelectionDAG &DAG = CLI.DAG;
  SDLoc &DL = CLI.DL;
  SDValue Chain = CLI.Chain;
  SDValue Callee = CLI.Callee;
  CallingConv::ID CallConv = CLI.CallConv;
  bool &IsTailCall = CLI.IsTailCall;
  const auto &Outs = CLI.Outs;
  const auto &OutVals = CLI.OutVals;
  const auto &Ins = CLI.Ins;
  MachineFunction &MF = DAG.getMachineFunction();

  // Stage 6a scope guards. Codex's stage-6 design pass insisted on hard
  // rejection here so any out-of-scope IR fails with a readable diagnostic
  // rather than mis-compiling.
  if (CallConv != CallingConv::C)
    report_fatal_error(
        "Mov: only CallingConv::C supported (stage 6a; fastcall/etc. later)");
  if (CLI.IsVarArg)
    report_fatal_error("Mov: vararg calls not yet supported (stage 6+)");
  for (const ISD::OutputArg &O : Outs) {
    // Stage 6b — accept sret + byval. sret is just a pointer arg
    // (caller-allocated return slot, pushed as the first cdecl arg);
    // byval is handled below by emitting a `getMemcpy` from the
    // source pointer to the outgoing stack slot instead of a plain
    // store. Both flags are common in Rust IR (trait returns
    // bigger than 4 bytes become sret; `&struct` borrowed args
    // sometimes use byval).
    if (O.Flags.isSRet()) {
      // sret pointer — just a regular i32 pointer arg from here on.
      // Don't apply the scalar-VT check; the pointer's VT is i32.
      continue;
    }
    if (O.Flags.isByVal()) {
      // byval — the per-arg loop below emits getMemcpy. The VT here
      // is just the pointer; the byval-size lives in Flags.
      continue;
    }
    if (O.VT != MVT::i1 && O.VT != MVT::i8 && O.VT != MVT::i16 &&
        O.VT != MVT::i32)
      report_fatal_error(
          "Mov: only i1/i8/i16/i32 scalar call args supported (stage 6a)");
  }
  // Stage 6b — two-i32 returns (EDX:EAX) are accepted now. RetCC_Mov
  // assigns the second i32 to EDX. Bigger aggregate returns route
  // through sret (handled above as a regular pointer arg).
  if (Ins.size() > 2)
    report_fatal_error(
        "Mov: returns wider than EDX:EAX must use sret (stage 6b only "
        "handles up to 8-byte register returns)");

  // Tail-call elimination not implemented; CallLoweringInfo asks us to
  // unset the flag rather than silently keep emitting a tail call.
  IsTailCall = false;

  // Analyze outgoing args against CC_Mov.
  SmallVector<CCValAssign, 8> ArgLocs;
  CCState CCInfo(CallConv, /*IsVarArg=*/false, MF, ArgLocs, *DAG.getContext());
  CCInfo.AnalyzeCallOperands(Outs, CC_Mov);
  const unsigned NumBytes = CCInfo.getStackSize();

  // CALLSEQ_START(NumBytes, 0) — reserves the outgoing-arg area.
  Chain = DAG.getCALLSEQ_START(Chain, NumBytes, 0, DL);

  // For each stack-passed arg, compute its address as ESP + offset and emit
  // a store. cdecl pushes are caller-cleaned; we emit them as plain stores
  // so DAGCombine can keep them in order via the chain.
  SmallVector<SDValue, 8> MemOpChains;
  const SDValue StackPtr =
      DAG.getCopyFromReg(Chain, DL, Mov::ESP,
                         getPointerTy(DAG.getDataLayout()));

  for (size_t i = 0; i < ArgLocs.size(); ++i) {
    CCValAssign &VA = ArgLocs[i];
    SDValue Arg = OutVals[i];
    const ISD::ArgFlagsTy &Flags = Outs[i].Flags;

    if (!VA.isMemLoc())
      report_fatal_error("Mov: register-passed call args unexpected (stage 6+)");

    // Stage 6b — byval struct passing. Source is a pointer to the
    // caller's struct; cdecl wants the struct's bytes copied to the
    // outgoing arg slot. Emit a getMemcpy with AlwaysInline=true so
    // SelectionDAG expands the copy in-line as i32 / byte stores
    // instead of synthesising a `call memcpy` libcall (our standalone
    // runtime does not link libc; a libcall would fail at link time).
    // Codex review: with AlwaysInline=false the threshold-based
    // expansion path could emit a libcall for large aggregates — a
    // silent correctness issue, since the call would land on an
    // unresolved external symbol.
    if (Flags.isByVal()) {
      const unsigned Size = Flags.getByValSize();
      const Align Alignment = Flags.getNonZeroByValAlign();
      SDValue SizeNode = DAG.getIntPtrConstant(Size, DL);
      SDValue Offset = DAG.getIntPtrConstant(VA.getLocMemOffset(), DL);
      SDValue Dst = DAG.getNode(ISD::ADD, DL,
                                getPointerTy(DAG.getDataLayout()),
                                StackPtr, Offset);
      SDValue MemcpyChain = DAG.getMemcpy(
          Chain, DL, Dst, Arg, SizeNode, Alignment,
          /*isVolatile=*/false, /*AlwaysInline=*/true,
          /*CI=*/nullptr, std::nullopt,
          MachinePointerInfo::getStack(MF, VA.getLocMemOffset()),
          MachinePointerInfo());
      MemOpChains.push_back(MemcpyChain);
      continue;
    }

    // CC_Mov stamps the LocInfo for promoted narrow args; widen back to
    // i32 before storing so the slot is 4 bytes wide.
    switch (VA.getLocInfo()) {
    case CCValAssign::Full:
      break;
    case CCValAssign::AExt:
      Arg = DAG.getNode(ISD::ANY_EXTEND, DL, VA.getLocVT(), Arg);
      break;
    case CCValAssign::ZExt:
      Arg = DAG.getNode(ISD::ZERO_EXTEND, DL, VA.getLocVT(), Arg);
      break;
    case CCValAssign::SExt:
      Arg = DAG.getNode(ISD::SIGN_EXTEND, DL, VA.getLocVT(), Arg);
      break;
    default:
      report_fatal_error("Mov: unexpected LocInfo in LowerCall");
    }

    // store i32 Arg, ptr [esp + VA.getLocMemOffset()]
    SDValue Offset = DAG.getIntPtrConstant(VA.getLocMemOffset(), DL);
    SDValue Addr =
        DAG.getNode(ISD::ADD, DL, getPointerTy(DAG.getDataLayout()), StackPtr,
                    Offset);
    MemOpChains.push_back(
        DAG.getStore(Chain, DL, Arg, Addr,
                     MachinePointerInfo::getStack(MF, VA.getLocMemOffset())));
  }

  if (!MemOpChains.empty())
    Chain = DAG.getNode(ISD::TokenFactor, DL, MVT::Other, MemOpChains);

  // Translate the callee operand to a usable form.
  //   - GlobalAddress / ExternalSymbol → Target* variant → CALL32d
  //     (DAGToDAG picks the opcode based on the resulting SDNode kind).
  //   - Anything else (load result, formal arg of function-pointer type,
  //     computed pointer, …) is left as a plain register-shaped SDValue
  //     and selected as CALL32r in DAGToDAG.
  if (auto *G = dyn_cast<GlobalAddressSDNode>(Callee)) {
    Callee = DAG.getTargetGlobalAddress(G->getGlobal(), DL,
                                        getPointerTy(DAG.getDataLayout()),
                                        /*offset=*/0);
  } else if (auto *E = dyn_cast<ExternalSymbolSDNode>(Callee)) {
    Callee = DAG.getTargetExternalSymbol(
        E->getSymbol(), getPointerTy(DAG.getDataLayout()));
  }

  // Build the MovISD::CALL: chain, callee, regmask, [glue].
  const auto *TRI = MF.getSubtarget().getRegisterInfo();
  const uint32_t *Mask = TRI->getCallPreservedMask(MF, CallConv);
  assert(Mask && "Mov: getCallPreservedMask must return non-null");

  SmallVector<SDValue, 4> Ops = {Chain, Callee, DAG.getRegisterMask(Mask)};

  SDVTList NodeTys = DAG.getVTList(MVT::Other, MVT::Glue);
  Chain = DAG.getNode(MovISD::CALL, DL, NodeTys, Ops);
  SDValue Glue = Chain.getValue(1);

  // CALLSEQ_END(NumBytes, 0) closes the call frame.
  Chain = DAG.getCALLSEQ_END(Chain, NumBytes, 0, Glue, DL);
  Glue = Chain.getValue(1);

  // Read back the return value (EAX) if there is one.
  SmallVector<CCValAssign, 2> RVLocs;
  CCState RetCCInfo(CallConv, /*IsVarArg=*/false, MF, RVLocs, *DAG.getContext());
  RetCCInfo.AnalyzeCallResult(Ins, RetCC_Mov);

  for (CCValAssign &VA : RVLocs) {
    assert(VA.isRegLoc() && "stage 6 RetCC always assigns to a register");
    SDValue Val = DAG.getCopyFromReg(Chain, DL, VA.getLocReg(),
                                     VA.getLocVT(), Glue);
    Chain = Val.getValue(1);
    Glue = Val.getValue(2);
    if (VA.getLocInfo() != CCValAssign::Full)
      Val = DAG.getNode(ISD::TRUNCATE, DL, VA.getValVT(), Val);
    InVals.push_back(Val);
  }
  return Chain;
}
