//===-- llvm-mov-llc.cpp - .ll -> mov-target asm driver -------------------===//
//
// Self-contained replacement for `llc -mtriple=mov-...`. We don't depend on
// stock `llc --load`-style plugin loading (it's brittle across distro builds);
// instead, we statically register the Mov target right here and run a tiny
// version of llc's codegen pipeline.
//
// Usage:
//   llvm-mov-llc input.ll [-o output.s]
//   echo '...' | llvm-mov-llc -o -
//
//===----------------------------------------------------------------------===//

#include "llvm/Analysis/TargetTransformInfo.h"
#include "llvm/CodeGen/CommandFlags.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/InstIterator.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/Intrinsics.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/LegacyPassManager.h"
#include "llvm/IR/Module.h"
#include "llvm/IRReader/IRReader.h"
#include "llvm/InitializePasses.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Pass.h"
#include "llvm/PassRegistry.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/InitLLVM.h"
#include "llvm/Support/SourceMgr.h"
#include "llvm/Support/ToolOutputFile.h"
#include "llvm/Support/WithColor.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Target/TargetMachine.h"
#include "llvm/Target/TargetOptions.h"
#include "llvm/TargetParser/Triple.h"
#include "llvm/Transforms/Scalar/Scalarizer.h"

using namespace llvm;

// Statically registered by the Mov target libraries; declared here so the
// linker pulls them in without -Wl,--whole-archive games.
extern "C" void LLVMInitializeMovTargetInfo();
extern "C" void LLVMInitializeMovTarget();
extern "C" void LLVMInitializeMovTargetMC();
extern "C" void LLVMInitializeMovAsmPrinter();

static cl::opt<std::string> InputFilename(cl::Positional,
                                          cl::desc("<input .ll | -> stdin>"),
                                          cl::init("-"));
static cl::opt<std::string> OutputFilename("o",
                                           cl::desc("Output filename ('-' for stdout)"),
                                           cl::value_desc("filename"),
                                           cl::init("-"));
static cl::opt<std::string> MTriple("mtriple",
                                    cl::desc("Override target triple"),
                                    cl::init("mov-unknown-linux-gnu"));

// Stage 7f2 — inject restoring-division IR definitions of the standard
// compiler-rt libcall helpers (__udivsi3 / __umodsi3 / __divsi3 /
// __modsi3) so that SDAG's Expand → libcall path for ISD::{UDIV,SDIV,
// UREM,SREM} resolves at link time without a user-crate stub. Each
// helper goes through the same codegen pipeline as user code: the
// Function-level rewrites below (i32 SELECT → bit-blend, sext-i1
// removal) are critical for compile time — a 32-iter loop with raw
// i32 SELECTs pushes DAG-ISel into the multi-minute pathology that
// motivated the SELECT-rewrite pass in the first place.
//
// Linkage is `linkonce_odr` so multiple translation units each
// emitting the helpers don't conflict at link time; the linker
// keeps one definition and discards the rest.
//
// Only invoked when the module contains at least one of the four
// div/rem IR opcodes whose **scalar element** type is i32. Checking
// the scalar element (`getScalarType`) — rather than the whole type —
// catches `udiv <N x i32>` shapes too: the driver's Scalarizer pass
// (stage 6d1, runs after this injection) will rewrite each lane into
// a scalar `udiv i32` whose SDAG Expand path ends up calling
// `__udivsi3`. Missing those at this scan would leave undefined
// helper symbols in the resulting object (codex-review P2).
static bool moduleNeedsDivRemHelpers(Module &M) {
  for (Function &F : M) {
    if (F.isDeclaration())
      continue;
    for (Instruction &I : instructions(F)) {
      switch (I.getOpcode()) {
      case Instruction::UDiv:
      case Instruction::SDiv:
      case Instruction::URem:
      case Instruction::SRem:
        if (I.getType()->getScalarType()->isIntegerTy(32))
          return true;
        break;
      default:
        break;
      }
    }
  }
  return false;
}


// Stage 7h1 — "bit-blend safe" marker for the i64 SELECT rewrite
// below. Every helper we inject is straight-line bit-arithmetic with
// no poison-introducing arms (we never emit `nsw` / `nuw` flags or
// other UB-bearing ops in helper bodies), so it's safe to rewrite
// their i64 `select`s into branchless `(a & m) | (b & ~m)` form. The
// rewrite is intentionally NOT applied to user-authored i64 selects,
// where a poison-arm select could be miscompiled by the bit-blend
// (codex-review P2 on stage 7h1 bring-up).
static constexpr llvm::StringLiteral kBitBlendAttr = "llvm-mov-bit-blend-safe";

static Function *makeOrPromoteHelper(Module &M, StringRef Name,
                                     FunctionType *Ty) {
  if (Function *Existing = M.getFunction(Name)) {
    // If user code (or a previous run) already defines the symbol,
    // leave it alone — the existing body wins.
    if (!Existing->isDeclaration())
      return nullptr;
    // Pure declaration left by SDAG-Expand prep. Upgrade to a
    // definition we own.
    Existing->setLinkage(GlobalValue::LinkOnceODRLinkage);
    Existing->addFnAttr(kBitBlendAttr);
    return Existing;
  }
  Function *F = Function::Create(Ty, GlobalValue::LinkOnceODRLinkage, Name, &M);
  F->setCallingConv(CallingConv::C);
  F->addFnAttr(kBitBlendAttr);
  return F;
}

// Forward decls for i64 emit utilities defined further down. The
// stage-7h9 i64↔f64 helpers (above their definitions) reuse them.
static Value *emitLshrI64ByI32(IRBuilder<> &B, Value *X, Value *Amt);
static Value *emitShlI64ByI32(IRBuilder<> &B, Value *X, Value *Amt);
static Value *emitCtlzI64(IRBuilder<> &B, Module &M, Value *X);

static void injectDivRemHelpers(Module &M, LLVMContext &Ctx) {
  Type *I32 = Type::getInt32Ty(Ctx);
  FunctionType *BinFnTy = FunctionType::get(I32, {I32, I32}, /*isVarArg=*/false);

  Function *UDiv = makeOrPromoteHelper(M, "__udivsi3", BinFnTy);
  Function *UMod = makeOrPromoteHelper(M, "__umodsi3", BinFnTy);
  Function *SDiv = makeOrPromoteHelper(M, "__divsi3",  BinFnTy);
  Function *SMod = makeOrPromoteHelper(M, "__modsi3",  BinFnTy);

  // Resolve `__udivsi3` once for the body builders that delegate to it.
  // The Module-level `getFunction` call lets the umod / sdiv / smod
  // bodies refer to the canonical declaration even when the user
  // already provided their own __udivsi3 (in which case `UDiv` above
  // is null and we don't rebuild the body, but the user's definition
  // is still what the call resolves to at link time).
  FunctionCallee UDivCallee = M.getOrInsertFunction("__udivsi3", BinFnTy);

  // __udivsi3 — 32-iter restoring long division.
  //   if d == 0: return 0     (matches the user stub semantics; SDAG
  //                            never lowers a div-by-zero in well-
  //                            formed IR, so this is a belt-and-braces
  //                            guard, not a code-path the tests hit.)
  //   r = q = 0
  //   for i in 31..=0:
  //     r = (r << 1) | ((n >> i) & 1)
  //     if r >= d: r -= d; q |= (1 << i)
  //   return q
  if (UDiv) {
    Argument *NArg = UDiv->getArg(0); NArg->setName("n");
    Argument *DArg = UDiv->getArg(1); DArg->setName("d");

    BasicBlock *Entry = BasicBlock::Create(Ctx, "entry",   UDiv);
    BasicBlock *Zero  = BasicBlock::Create(Ctx, "ret_zero",UDiv);
    BasicBlock *Loop  = BasicBlock::Create(Ctx, "loop",    UDiv);
    BasicBlock *Exit  = BasicBlock::Create(Ctx, "exit",    UDiv);

    IRBuilder<> B(Entry);
    Value *DZero = B.CreateICmpEQ(DArg, B.getInt32(0));
    B.CreateCondBr(DZero, Zero, Loop);

    B.SetInsertPoint(Zero);
    B.CreateRet(B.getInt32(0));

    B.SetInsertPoint(Loop);
    PHINode *IPhi = B.CreatePHI(I32, 2, "i");
    PHINode *RPhi = B.CreatePHI(I32, 2, "r");
    PHINode *QPhi = B.CreatePHI(I32, 2, "q");
    IPhi->addIncoming(B.getInt32(31), Entry);
    RPhi->addIncoming(B.getInt32(0),  Entry);
    QPhi->addIncoming(B.getInt32(0),  Entry);

    Value *Bit    = B.CreateAnd(B.CreateLShr(NArg, IPhi), B.getInt32(1));
    Value *RShift = B.CreateShl(RPhi, B.getInt32(1));
    Value *RCand  = B.CreateOr(RShift, Bit);
    Value *Take   = B.CreateICmpUGE(RCand, DArg);
    Value *RSub   = B.CreateSub(RCand, DArg);
    Value *QSet   = B.CreateOr(QPhi, B.CreateShl(B.getInt32(1), IPhi));
    Value *RNext  = B.CreateSelect(Take, RSub, RCand);
    Value *QNext  = B.CreateSelect(Take, QSet, QPhi);
    Value *INext  = B.CreateSub(IPhi, B.getInt32(1));
    Value *Done   = B.CreateICmpSLT(INext, B.getInt32(0));
    B.CreateCondBr(Done, Exit, Loop);

    IPhi->addIncoming(INext, Loop);
    RPhi->addIncoming(RNext, Loop);
    QPhi->addIncoming(QNext, Loop);

    B.SetInsertPoint(Exit);
    // QPhi is the SSA value at the loop header; the loop's final
    // iteration writes QNext into it via the back-edge. Returning
    // QPhi from Exit reads the post-loop value (the same one PHI
    // would hold on entry to a hypothetical next iteration).
    PHINode *QOut = B.CreatePHI(I32, 1, "q.out");
    QOut->addIncoming(QNext, Loop);
    B.CreateRet(QOut);
  }

  // __umodsi3(n, d) = n - __udivsi3(n, d) * d
  // The `*` here is a real i32 MUL, which stage 7f1's MUL32rr already
  // covers — no extra plumbing needed.
  if (UMod) {
    Argument *NArg = UMod->getArg(0); NArg->setName("n");
    Argument *DArg = UMod->getArg(1); DArg->setName("d");
    BasicBlock *BB = BasicBlock::Create(Ctx, "entry", UMod);
    IRBuilder<> B(BB);
    Value *Q  = B.CreateCall(UDivCallee, {NArg, DArg});
    Value *QD = B.CreateMul(Q, DArg);
    Value *R  = B.CreateSub(NArg, QD);
    B.CreateRet(R);
  }

  // __divsi3(a, b) — signed; sign(q) = sign(a) ^ sign(b).
  //   neg   = (a < 0) ^ (b < 0)
  //   |a|   = a < 0 ? -a : a
  //   |b|   = b < 0 ? -b : b
  //   q     = __udivsi3(|a|, |b|)
  //   return neg ? -q : q
  if (SDiv) {
    Argument *AArg = SDiv->getArg(0); AArg->setName("a");
    Argument *BArg = SDiv->getArg(1); BArg->setName("b");
    BasicBlock *BB = BasicBlock::Create(Ctx, "entry", SDiv);
    IRBuilder<> B(BB);
    Value *Zero = B.getInt32(0);
    Value *ANeg = B.CreateICmpSLT(AArg, Zero);
    Value *BNeg = B.CreateICmpSLT(BArg, Zero);
    // CreateXor on i1s -> i1, exactly the sign-flip predicate.
    Value *SignFlip = B.CreateXor(ANeg, BNeg);
    Value *AbsA = B.CreateSelect(ANeg, B.CreateSub(Zero, AArg), AArg);
    Value *AbsB = B.CreateSelect(BNeg, B.CreateSub(Zero, BArg), BArg);
    Value *Q    = B.CreateCall(UDivCallee, {AbsA, AbsB});
    Value *NegQ = B.CreateSub(Zero, Q);
    Value *R    = B.CreateSelect(SignFlip, NegQ, Q);
    B.CreateRet(R);
  }

  // __modsi3(a, b) — signed; sign(r) = sign(a) (C / Rust convention).
  //   |a| = ... ; |b| = ...
  //   q   = __udivsi3(|a|, |b|)
  //   r   = |a| - q * |b|
  //   return a < 0 ? -r : r
  if (SMod) {
    Argument *AArg = SMod->getArg(0); AArg->setName("a");
    Argument *BArg = SMod->getArg(1); BArg->setName("b");
    BasicBlock *BB = BasicBlock::Create(Ctx, "entry", SMod);
    IRBuilder<> B(BB);
    Value *Zero = B.getInt32(0);
    Value *ANeg = B.CreateICmpSLT(AArg, Zero);
    Value *BNeg = B.CreateICmpSLT(BArg, Zero);
    Value *AbsA = B.CreateSelect(ANeg, B.CreateSub(Zero, AArg), AArg);
    Value *AbsB = B.CreateSelect(BNeg, B.CreateSub(Zero, BArg), BArg);
    Value *Q    = B.CreateCall(UDivCallee, {AbsA, AbsB});
    Value *QD   = B.CreateMul(Q, AbsB);
    Value *AbsR = B.CreateSub(AbsA, QD);
    Value *NegR = B.CreateSub(Zero, AbsR);
    Value *R    = B.CreateSelect(ANeg, NegR, AbsR);
    B.CreateRet(R);
  }
}

// Stage 7g1 — inject `__addsf3` (IEEE-754 single-precision add).
//
// SDAG's soft-float legalizer turns each `fadd float` into a libcall
// against `__addsf3 (float, float) -> float`. We provide the body
// here, using the same `linkonce_odr` pattern as the integer DIV/REM
// helpers. The body is straight-line (no internal branches): every
// "if" in the standard textbook algorithm is rewritten as an
// `i1`-conditioned `select`, so the driver's existing SELECT →
// bit-blend pass (around the 6d3e era) lowers them to mov-only-
// friendly straight-line arithmetic instead of CMP+Jcc+PHI loops
// that would otherwise pin DAG-ISel.
//
// Limitations of this first-cut implementation:
//   - Inf / NaN inputs propagate as best-effort; specifically a NaN
//     input may surface as a finite garbage output. The four
//     fadd_*.ll fixtures stay in the normal range and don't tickle
//     this; following stages can add the NaN / Inf paths.
//   - Subnormal inputs are flushed to zero (exp == 0 ⇒ value == 0).
//   - Subnormal result is flushed to zero (underflow → +0 with the
//     surviving sign).
//   - Rounding: round-to-nearest, ties-to-even, with one guard bit +
//     a sticky bit synthesised from the bits shifted out during
//     alignment. Matches the C `+` operator on x86-64 for the
//     fixture range; differs in the LSB for edge-case rounding.
//
// Variable layout (all i32 unless noted, mantissas carry an extra
// 3-bit guard region — see comments inline):
//
//   ai, bi          : the IEEE-754 bit patterns of the two inputs
//   sa, sb          : sign bits   (ai >> 31)
//   ea, eb          : biased exponents (8 bits)
//   ma_raw, mb_raw  : mantissa fields (23 bits)
//   ma_g, mb_g      : (mantissa | implicit-1) << 3  — bit 26 is MSB
//   a_ge_b          : i1, ea >= eb
//   re_init         : max(ea, eb), the "tentative" result exponent
//   ed              : |ea - eb|, capped at 31 to keep shifts well-
//                     defined
//   mLarge, mSmall  : the (g)-form mantissas in (larger, smaller)
//                     exponent order; sLarge/sSmall are the matching
//                     signs
//   shifted         : mSmall lshr ed, then OR'd with a 1-bit sticky
//                     that captures whether any bit was dropped
//   sum_same / sum_diff : straight-add and straight-sub of the two
//                     aligned mantissas, both kept around so the
//                     final `select i1 signs_equal` picks one
//   mSum            : selected magnitude pre-normalise; sign comes
//                     from `sLarge` when adding, or from the side
//                     with the larger magnitude when subtracting
//   lz              : ctlz(mSum). bit 26 = "normal", bit 27 = post-
//                     add carry-out, lz > 5 = subtraction left-
//                     normalises
//   ... rounding / packing follow at the bottom.
static void injectAddSf3Helper(Module &M, LLVMContext &Ctx) {
  Type *F32 = Type::getFloatTy(Ctx);
  Type *I32 = Type::getInt32Ty(Ctx);
  FunctionType *FnTy = FunctionType::get(F32, {F32, F32}, /*isVarArg=*/false);

  Function *F = makeOrPromoteHelper(M, "__addsf3", FnTy);
  if (!F)
    return;

  F->getArg(0)->setName("a");
  F->getArg(1)->setName("b");

  BasicBlock *Entry = BasicBlock::Create(Ctx, "entry", F);
  IRBuilder<> B(Entry);

  auto C = [&](uint32_t V) { return B.getInt32(V); };

  Value *AI = B.CreateBitCast(F->getArg(0), I32, "ai");
  Value *BI = B.CreateBitCast(F->getArg(1), I32, "bi");

  // Field extraction.
  Value *SA = B.CreateLShr(AI, C(31), "sa");
  Value *SB = B.CreateLShr(BI, C(31), "sb");
  Value *EA = B.CreateAnd(B.CreateLShr(AI, C(23)), C(0xFFu), "ea");
  Value *EB = B.CreateAnd(B.CreateLShr(BI, C(23)), C(0xFFu), "eb");
  Value *MARaw = B.CreateAnd(AI, C(0x7FFFFFu), "ma_raw");
  Value *MBRaw = B.CreateAnd(BI, C(0x7FFFFFu), "mb_raw");

  // Implicit-1, then shift left by 3 to make room for guard+round+
  // sticky bits at the bottom. The "normalised" mantissa now has its
  // MSB at bit 26 (= 23 + 3).
  Value *MAN = B.CreateOr(MARaw, C(0x800000u));
  Value *MBN = B.CreateOr(MBRaw, C(0x800000u));
  Value *MAG = B.CreateShl(MAN, C(3), "ma_g");
  Value *MBG = B.CreateShl(MBN, C(3), "mb_g");

  // Order by *magnitude*, not by exponent alone. When ea == eb but the
  // signs differ, the operand with the larger mantissa is the one
  // whose sign survives in the result; ordering by exponent only
  // would pick whichever operand is on the left and feed an unsigned
  // underflow into the m_large - m_small subtract (codex-review P1
  // on inputs like `1.0 + -1.5`). Stripping the sign bit and
  // comparing the magnitude as unsigned i32 is a single compare:
  // when ea > eb the exponent dominates, when ea == eb the mantissas
  // decide.
  Value *AMag = B.CreateAnd(AI, C(0x7FFFFFFFu));
  Value *BMag = B.CreateAnd(BI, C(0x7FFFFFFFu));
  Value *AGeB = B.CreateICmpUGE(AMag, BMag, "a_ge_b");
  Value *ReInit = B.CreateSelect(AGeB, EA, EB, "re_init");
  Value *EDab = B.CreateSub(EA, EB);
  Value *EDba = B.CreateSub(EB, EA);
  Value *EDraw = B.CreateSelect(AGeB, EDab, EDba, "ed_raw");
  // Cap ed to 31 so the alignment shifts stay defined; bits beyond
  // 31 places contribute only sticky-bit, and we OR a guaranteed-
  // non-zero sticky onto the shifted result when ed >= 24 anyway
  // (the shifted mantissa is zero by then).
  Value *EDtooBig = B.CreateICmpUGT(EDraw, C(31u));
  Value *ED = B.CreateSelect(EDtooBig, C(31u), EDraw, "ed");

  Value *MLarge = B.CreateSelect(AGeB, MAG, MBG, "m_large");
  Value *MSmall = B.CreateSelect(AGeB, MBG, MAG, "m_small");
  Value *SLarge = B.CreateSelect(AGeB, SA, SB, "s_large");
  Value *SSmall = B.CreateSelect(AGeB, SB, SA, "s_small");

  // Sticky bit = "any of the bits we are about to discard is set".
  //   discarded = m_small - ((m_small >> ed) << ed)
  // Both shifts use `ed` ∈ [0, 31] (UB-free). Avoids the
  // `shl 32`-when-ed-is-zero hazard of the "shift to top" trick.
  Value *MSmallRight = B.CreateLShr(MSmall, ED);
  Value *MSmallBack  = B.CreateShl(MSmallRight, ED);
  Value *Discarded   = B.CreateSub(MSmall, MSmallBack);
  Value *StickyI1    = B.CreateICmpNE(Discarded, C(0));
  Value *Sticky      = B.CreateZExt(StickyI1, I32, "sticky");
  // Plus: if ed was capped to 31 from a larger original, *any* bit of
  // the smaller mantissa contributes to sticky (it was 0 after the
  // 31-bit lshr above, but the original m_small was non-zero by virtue
  // of carrying an implicit 1). Catch that here too.
  Value *MSmallNonzero = B.CreateICmpNE(MSmall, C(0));
  Value *StickyExtra   = B.CreateAnd(B.CreateZExt(EDtooBig, I32),
                                     B.CreateZExt(MSmallNonzero, I32));
  Value *StickyAll     = B.CreateOr(Sticky, StickyExtra);

  Value *MSmallShifted = B.CreateOr(MSmallRight, StickyAll, "m_small_shifted");

  // Same-sign add, different-sign subtract.
  Value *SignsEqual = B.CreateICmpEQ(SLarge, SSmall);
  Value *SumAdd = B.CreateAdd(MLarge, MSmallShifted);
  Value *SumSub = B.CreateSub(MLarge, MSmallShifted); // m_large >= shifted because exp_large > exp_small
  Value *MSum = B.CreateSelect(SignsEqual, SumAdd, SumSub, "m_sum");

  // Cancel-to-zero — opposite signs with identical magnitudes.
  Value *CancelZero = B.CreateAnd(B.CreateNot(SignsEqual),
                                  B.CreateICmpEQ(MSum, C(0)));

  // Normalise. mSum currently has its MSB somewhere in bits 0..27:
  //   bit 27 = add overflow  (lz == 4)
  //   bit 26 = "normal"      (lz == 5)
  //   bit  k < 26 = subtraction left-normalises by (5 - lz)
  // Use ctlz to compute the shift count branchlessly.
  Function *Ctlz = Intrinsic::getOrInsertDeclaration(&M, Intrinsic::ctlz, {I32});
  Value *LZ = B.CreateCall(Ctlz, {MSum, ConstantInt::getFalse(Ctx)}, "lz");

  // Overflow path (lz == 4): shift right by 1 with sticky.
  Value *LzEq4 = B.CreateICmpEQ(LZ, C(4u));
  Value *StickyOverflow = B.CreateAnd(MSum, C(1u));
  Value *MSumOvf = B.CreateOr(B.CreateLShr(MSum, C(1)), StickyOverflow);
  Value *ReOvf  = B.CreateAdd(ReInit, C(1u));

  // Underflow path (lz > 5): shift left by min(lz - 5, re_init - 1).
  // The lower bound on re_init - 1 protects against generating a
  // denormal result; if the shift would push below exp == 1 we cap
  // and let the round-trip below flush to zero via the exponent < 1
  // check.
  //
  // Belt-and-braces clamping (codex-review P1): the underflow arm is
  // evaluated unconditionally inside the straight-line body. When the
  // selected path is actually "lz == 4" (post-add carry-out, common
  // for same-sign sums like `1.5 + 1.5`), `lz - 5` underflows to
  // 0xFFFFFFFF and `re_init - 1` is whatever the larger exponent
  // happened to be — often well above 31. The later SELECT → bit-
  // blend rewrite evaluates *both* arms, so a `shl mSum, > 31`
  // appears in the lowered MIR even though the bit-blend's mask
  // discards its result. We clamp the shift count to a safe range
  // (≤ 26, the mantissa-width-bounded normalize maximum) so the
  // emitted shift is always well-defined regardless of which arm
  // the final select chooses.
  Value *LzGt5     = B.CreateICmpUGT(LZ, C(5u));
  Value *LzMinus5Safe =
      B.CreateSelect(LzGt5, B.CreateSub(LZ, C(5u)), C(0u));
  Value *MaxShift  = B.CreateSub(ReInit, C(1u));
  Value *ShiftA    = B.CreateSelect(
      B.CreateICmpULT(LzMinus5Safe, MaxShift), LzMinus5Safe, MaxShift);
  // Final shift-width clamp. 26 is enough to fully normalise any
  // 27-bit mantissa we can produce; clamping here keeps the shift
  // amount in i32-shift's defined range [0, 31] no matter what
  // ReInit happened to be.
  Value *ShiftCap  = B.CreateSelect(
      B.CreateICmpULT(ShiftA, C(26u)), ShiftA, C(26u));
  Value *MSumUnf   = B.CreateShl(MSum, ShiftCap);
  Value *ReUnf     = B.CreateSub(ReInit, ShiftCap);

  // Combine. lz == 4 → overflow; lz > 5 → underflow; else → normal.
  Value *MSumPost = B.CreateSelect(LzEq4, MSumOvf,
                       B.CreateSelect(LzGt5, MSumUnf, MSum));
  Value *RePost = B.CreateSelect(LzEq4, ReOvf,
                       B.CreateSelect(LzGt5, ReUnf, ReInit));

  // Round to nearest, ties to even.
  Value *GuardBit = B.CreateAnd(B.CreateLShr(MSumPost, C(2)), C(1u));
  Value *RoundBit = B.CreateAnd(B.CreateLShr(MSumPost, C(1)), C(1u));
  Value *StickyBit2 = B.CreateAnd(MSumPost, C(1u));
  Value *MSumTrunc = B.CreateLShr(MSumPost, C(3));
  Value *Lsb = B.CreateAnd(MSumTrunc, C(1u));
  Value *RoundOrSticky = B.CreateOr(RoundBit, StickyBit2);
  Value *RoundOrLsb    = B.CreateOr(RoundOrSticky, Lsb);
  Value *NeedRoundUp   = B.CreateAnd(GuardBit, RoundOrLsb);
  Value *MSumRounded   = B.CreateAdd(MSumTrunc, NeedRoundUp);

  // Round may push mantissa to 0x1000000 → bump exponent, shift down.
  Value *RoundedOvf = B.CreateICmpEQ(MSumRounded, C(0x1000000u));
  Value *MSumFinal  = B.CreateSelect(RoundedOvf,
                                     B.CreateLShr(MSumRounded, C(1)),
                                     MSumRounded);
  Value *ReFinalRaw = B.CreateSelect(RoundedOvf, B.CreateAdd(RePost, C(1u)),
                                     RePost);

  // Pack the IEEE-754 fields back.
  Value *MantField  = B.CreateAnd(MSumFinal, C(0x7FFFFFu));
  Value *ExpField   = B.CreateAnd(B.CreateShl(ReFinalRaw, C(23)),
                                  C(0x7F800000u));
  Value *SignField  = B.CreateShl(SLarge, C(31));
  Value *Packed     = B.CreateOr(SignField,
                                 B.CreateOr(ExpField, MantField));

  // Exponent overflow → Inf with the result sign.
  Value *ExpOvf = B.CreateICmpUGE(ReFinalRaw, C(255u));
  Value *InfBits = B.CreateOr(B.CreateShl(SLarge, C(31)), C(0x7F800000u));
  Value *PostOvf = B.CreateSelect(ExpOvf, InfBits, Packed);

  // Special-case handling: zero / denormal inputs flush to "pass the
  // other through". This also catches "0 + 0 = 0" naturally (both
  // sides are zero, so PostOvf path could produce -0; here we end at
  // the b-input side, which is +0 in the fixtures).
  Value *AIsZero = B.CreateICmpEQ(EA, C(0u));
  Value *BIsZero = B.CreateICmpEQ(EB, C(0u));
  Value *Step1 = B.CreateSelect(AIsZero, BI, PostOvf);
  Value *Step2 = B.CreateSelect(BIsZero, AI, Step1);
  Value *Step3 = B.CreateSelect(CancelZero, C(0u), Step2);

  // Stage 7g4 — Inf / NaN propagation overrides the loop-body result.
  //
  //   - NaN input             → canonical qNaN (0x7FC00000)
  //   - Inf + Inf (same sign) → signed Inf with that sign
  //   - Inf + (-Inf)          → NaN  (IEEE indeterminate)
  //   - Inf + finite          → Inf preserved from the Inf operand
  //
  // Detection: exp == 0xFF distinguishes Inf/NaN from finites;
  // mant_raw != 0 distinguishes NaN from Inf. The overrides apply at
  // the very end so they win over the existing zero / cancellation
  // / overflow paths (which would, for example, route Inf + Inf to
  // signed Inf via the er-overflow gate but route Inf + (-Inf) to
  // signed zero via CancelZero — wrong for IEEE).
  Value *EAMax = B.CreateICmpEQ(EA, C(0xFFu));
  Value *EBMax = B.CreateICmpEQ(EB, C(0xFFu));
  Value *MANonZero = B.CreateICmpNE(MARaw, C(0u));
  Value *MBNonZero = B.CreateICmpNE(MBRaw, C(0u));
  Value *AIsNaN = B.CreateAnd(EAMax, MANonZero);
  Value *BIsNaN = B.CreateAnd(EBMax, MBNonZero);
  Value *AIsInf = B.CreateAnd(EAMax, B.CreateNot(MANonZero));
  Value *BIsInf = B.CreateAnd(EBMax, B.CreateNot(MBNonZero));
  Value *BothInf = B.CreateAnd(AIsInf, BIsInf);
  Value *SignSame = B.CreateICmpEQ(SA, SB);
  Value *InfMinusInf = B.CreateAnd(BothInf, B.CreateNot(SignSame));
  Value *EitherNaN = B.CreateOr(AIsNaN, BIsNaN);
  Value *NaNCase = B.CreateOr(EitherNaN, InfMinusInf);
  // Inf preservation: pick the Inf operand's bits so the result
  // sign matches the surviving Inf side. When both are Inf with the
  // same sign, AI and BI are equal (mant == 0), so either works.
  Value *AnyInf = B.CreateOr(AIsInf, BIsInf);
  Value *InfBitsPick = B.CreateSelect(AIsInf, AI, BI);

  Value *WithInf = B.CreateSelect(AnyInf, InfBitsPick, Step3);
  Value *WithNaN = B.CreateSelect(NaNCase, C(0x7FC00000u), WithInf);

  Value *Result = B.CreateBitCast(WithNaN, F32);
  B.CreateRet(Result);
}

// Stage 7g1 — `__subsf3 (a, b)` = `__addsf3 (a, -b)`. Flip the sign
// bit of `b` and delegate. The injected `__addsf3` already handles
// every shape (carry-out, opposite-sign cancellation, magnitude
// ordering), so subtraction is essentially free.
static void injectSubSf3Helper(Module &M, LLVMContext &Ctx) {
  Type *F32 = Type::getFloatTy(Ctx);
  Type *I32 = Type::getInt32Ty(Ctx);
  FunctionType *FnTy = FunctionType::get(F32, {F32, F32}, /*isVarArg=*/false);
  Function *F = makeOrPromoteHelper(M, "__subsf3", FnTy);
  if (!F)
    return;
  F->getArg(0)->setName("a");
  F->getArg(1)->setName("b");

  // __addsf3 must exist by the time this runs (the entry-point caller
  // injects __addsf3 first when fadd or fsub is present).
  FunctionCallee AddSf3 =
      M.getOrInsertFunction("__addsf3", FnTy);

  BasicBlock *BB = BasicBlock::Create(Ctx, "entry", F);
  IRBuilder<> B(BB);
  Value *BI = B.CreateBitCast(F->getArg(1), I32);
  Value *NegBI = B.CreateXor(BI, B.getInt32(0x80000000u));
  Value *NegB = B.CreateBitCast(NegBI, F32);
  Value *R = B.CreateCall(AddSf3, {F->getArg(0), NegB});
  B.CreateRet(R);
}

// Stage 7g2 — IEEE-754 single-precision multiply: `__mulsf3 (a, b)`.
//
// Shape:
//   1. Extract sign / exp / mantissa fields from both inputs and add
//      the implicit-1 to get 24-bit ma / mb.
//   2. 24x24 -> 48-bit unsigned multiply via a 16-low + 8-high split:
//      `mul i32` is restricted to 32-bit results, so each partial
//      product (16x16, 16x8, 8x16, 8x8) fits and we sum them by hand
//      into a {high16, low32} pair. The "low + (mid_lo << 16)" add
//      can carry; carry detection is the standard "sum < operand"
//      trick.
//   3. Normalise: the 48-bit product sits in `[2^46, 2^48)`, so the
//      MSB is either bit 47 ("case A", e.g. 3.0*3.0) or bit 46 ("case
//      B", e.g. 2.0*3.0). Case A extracts bits [47:24] and bumps the
//      exponent by 1; case B extracts bits [46:23].
//   4. Round-to-nearest-ties-to-even with guard / sticky / lsb. Round
//      may push the mantissa to `0x1000000`; if so, shift right by 1
//      and bump the exponent again.
//   5. Pack {sign, exp, mant}. Overflow (exp >= 255) -> signed Inf;
//      underflow (exp <= 0) and either-input-zero -> signed zero.
//      Inf / NaN propagation is deferred (matches the existing
//      `__addsf3` scope).
//
// As with `__addsf3`, the body is straight-line IR with `select`
// instead of branches. The SELECT -> bit-blend rewrite materialises
// both arms of every `select`, so shift counts and mul operands are
// pre-computed to stay in a defined range no matter which arm the
// final blend picks (here we use only fixed-count shifts and unsigned
// adds, so no further clamping is needed).
static void injectMulSf3Helper(Module &M, LLVMContext &Ctx) {
  Type *F32 = Type::getFloatTy(Ctx);
  Type *I32 = Type::getInt32Ty(Ctx);
  FunctionType *FnTy = FunctionType::get(F32, {F32, F32}, /*isVarArg=*/false);

  Function *F = makeOrPromoteHelper(M, "__mulsf3", FnTy);
  if (!F)
    return;

  F->getArg(0)->setName("a");
  F->getArg(1)->setName("b");

  BasicBlock *Entry = BasicBlock::Create(Ctx, "entry", F);
  IRBuilder<> B(Entry);
  auto C = [&](uint32_t V) { return B.getInt32(V); };

  Value *AI = B.CreateBitCast(F->getArg(0), I32, "ai");
  Value *BI = B.CreateBitCast(F->getArg(1), I32, "bi");

  // Field extraction.
  Value *SA = B.CreateLShr(AI, C(31), "sa");
  Value *SB = B.CreateLShr(BI, C(31), "sb");
  Value *EA = B.CreateAnd(B.CreateLShr(AI, C(23)), C(0xFFu), "ea");
  Value *EB = B.CreateAnd(B.CreateLShr(BI, C(23)), C(0xFFu), "eb");
  Value *MARaw = B.CreateAnd(AI, C(0x7FFFFFu), "ma_raw");
  Value *MBRaw = B.CreateAnd(BI, C(0x7FFFFFu), "mb_raw");

  // Result sign = XOR of input signs (works for +/- zero too).
  Value *SR = B.CreateXor(SA, SB, "sr");

  // Either-zero short-circuit. Treat denormals (exp == 0) as zero in
  // line with the rest of our soft-float helpers' flush-to-zero scope.
  Value *AIsZero = B.CreateICmpEQ(EA, C(0u));
  Value *BIsZero = B.CreateICmpEQ(EB, C(0u));
  Value *EitherZero = B.CreateOr(AIsZero, BIsZero, "either_zero");

  // Add the implicit-1 to each mantissa. Both ma and mb are now 24 bits.
  Value *MA = B.CreateOr(MARaw, C(0x800000u), "ma");
  Value *MB = B.CreateOr(MBRaw, C(0x800000u), "mb");

  // 24x24 -> 48-bit unsigned multiply via 16-low + 8-high split.
  Value *ALo = B.CreateAnd(MA, C(0xFFFFu), "a_lo");
  Value *AHi = B.CreateLShr(MA, C(16), "a_hi");
  Value *BLo = B.CreateAnd(MB, C(0xFFFFu), "b_lo");
  Value *BHi = B.CreateLShr(MB, C(16), "b_hi");

  // Partial products — each fits in i32 unsigned.
  //   p_ll: 16x16 <= 0xFFFE0001  (32 bits)
  //   p_lh: 16x 8 <= 0x00FEFF01  (24 bits)
  //   p_hl:  8x16 <= 0x00FEFF01
  //   p_hh:  8x 8 <= 0x0000FE01  (16 bits)
  Value *Pll = B.CreateMul(ALo, BLo, "p_ll");
  Value *Plh = B.CreateMul(ALo, BHi, "p_lh");
  Value *Phl = B.CreateMul(AHi, BLo, "p_hl");
  Value *Phh = B.CreateMul(AHi, BHi, "p_hh");

  // Mid lane: `(p_lh + p_hl)`, up to 25 bits. Split into bits [15:0]
  // (contributed to `low`) and bits [24:16] (contributed to `high`).
  Value *Mid = B.CreateAdd(Plh, Phl, "mid");
  Value *MidLo = B.CreateAnd(Mid, C(0xFFFFu));
  Value *MidHi = B.CreateLShr(Mid, C(16));

  // Assemble the low 32 bits of the 48-bit product. The add can carry
  // out (e.g. for ma == mb == 0xFFFFFF), so detect it via the
  // "sum < addend" trick — `low < Pll` iff the unsigned add wrapped.
  Value *MidLoShifted = B.CreateShl(MidLo, C(16));
  Value *Low = B.CreateAdd(Pll, MidLoShifted, "low");
  Value *CarryI1 = B.CreateICmpULT(Low, Pll);
  Value *Carry = B.CreateZExt(CarryI1, I32, "carry");

  // High 16 bits of the 48-bit product. Phh fits in 16 bits, MidHi
  // fits in 9, plus the at-most-1 carry, so High fits in 17 bits but
  // never overflows i32.
  Value *High = B.CreateAdd(B.CreateAdd(Phh, MidHi), Carry, "high");

  // Normalize. The 48-bit product is in `[2^46, 2^48)`; the MSB is
  // bit 47 ("case A") or bit 46 ("case B"). `High & 0x8000` tells
  // which one.
  Value *TopBit47I1 = B.CreateICmpNE(B.CreateAnd(High, C(0x8000u)),
                                     C(0u), "top_bit_47");

  // Case A: product in [2^47, 2^48). Kept mantissa bits = [47:24].
  // Guard = bit 23, sticky = bits [22:0].
  Value *MantPreA = B.CreateOr(B.CreateShl(High, C(8)),
                               B.CreateLShr(Low, C(24)), "mant_pre_a");
  Value *GuardA = B.CreateAnd(B.CreateLShr(Low, C(23)), C(1u));
  Value *StickyAI1 = B.CreateICmpNE(B.CreateAnd(Low, C(0x7FFFFFu)), C(0u));
  Value *StickyA = B.CreateZExt(StickyAI1, I32);
  Value *LsbA = B.CreateAnd(MantPreA, C(1u));
  Value *RoundUpA = B.CreateAnd(GuardA, B.CreateOr(StickyA, LsbA));
  Value *MantRoundedA = B.CreateAdd(MantPreA, RoundUpA);
  Value *MantOvfA = B.CreateICmpEQ(MantRoundedA, C(0x1000000u));
  Value *MantPostA = B.CreateSelect(MantOvfA,
                                    B.CreateLShr(MantRoundedA, C(1)),
                                    MantRoundedA, "mant_post_a");

  // Case B: product in [2^46, 2^47). Kept mantissa bits = [46:23].
  // Guard = bit 22, sticky = bits [21:0].
  Value *MantPreB = B.CreateOr(B.CreateShl(High, C(9)),
                               B.CreateLShr(Low, C(23)), "mant_pre_b");
  Value *GuardB = B.CreateAnd(B.CreateLShr(Low, C(22)), C(1u));
  Value *StickyBI1 = B.CreateICmpNE(B.CreateAnd(Low, C(0x3FFFFFu)), C(0u));
  Value *StickyB = B.CreateZExt(StickyBI1, I32);
  Value *LsbB = B.CreateAnd(MantPreB, C(1u));
  Value *RoundUpB = B.CreateAnd(GuardB, B.CreateOr(StickyB, LsbB));
  Value *MantRoundedB = B.CreateAdd(MantPreB, RoundUpB);
  Value *MantOvfB = B.CreateICmpEQ(MantRoundedB, C(0x1000000u));
  Value *MantPostB = B.CreateSelect(MantOvfB,
                                    B.CreateLShr(MantRoundedB, C(1)),
                                    MantRoundedB, "mant_post_b");

  // Result exponent. ExpSum fits in i32 cleanly (each side <= 0xFF).
  // Case A: er = expSum - 127 + 1; case B: er = expSum - 127.
  Value *ExpSum = B.CreateAdd(EA, EB, "exp_sum");
  Value *ErA = B.CreateSub(ExpSum, C(126u));
  Value *ErAFinal = B.CreateSelect(MantOvfA,
                                   B.CreateAdd(ErA, C(1u)), ErA);
  Value *ErB = B.CreateSub(ExpSum, C(127u));
  Value *ErBFinal = B.CreateSelect(MantOvfB,
                                   B.CreateAdd(ErB, C(1u)), ErB);

  // Pick the normalised case.
  Value *MantPost = B.CreateSelect(TopBit47I1, MantPostA, MantPostB,
                                   "mant_post");
  Value *ErFinal = B.CreateSelect(TopBit47I1, ErAFinal, ErBFinal,
                                  "er_final");

  // Pack.
  Value *MantField = B.CreateAnd(MantPost, C(0x7FFFFFu));
  Value *ExpField = B.CreateAnd(B.CreateShl(ErFinal, C(23)),
                                C(0x7F800000u));
  Value *SignField = B.CreateShl(SR, C(31));
  Value *Packed = B.CreateOr(SignField,
                             B.CreateOr(ExpField, MantField));

  // Underflow / overflow. ErFinal is signed: <= 0 -> flush to signed
  // zero, >= 255 -> signed Inf. (Out-of-range exp values wrap into the
  // high i32 range, so we use signed comparisons here.)
  Value *Underflow = B.CreateICmpSLE(ErFinal, C(0), "underflow");
  Value *Overflow = B.CreateICmpSGE(ErFinal, C(255), "overflow");
  Value *SignedZero = SignField;
  Value *SignedInf = B.CreateOr(SignField, C(0x7F800000u));

  Value *Result = B.CreateSelect(Overflow, SignedInf, Packed);
  Result = B.CreateSelect(Underflow, SignedZero, Result);
  Result = B.CreateSelect(EitherZero, SignedZero, Result);

  // Stage 7g4 — Inf / NaN propagation:
  //   - NaN input            → canonical qNaN
  //   - 0 * Inf, Inf * 0     → NaN  (IEEE indeterminate)
  //   - Inf * finite (≠ 0)   → signed Inf with sr
  //   - Inf * Inf            → signed Inf with sr
  // Inf override comes before NaN override so 0 * Inf falls through
  // to NaN (Inf wins over the EitherZero gate but NaN wins over Inf).
  Value *EAMaxM = B.CreateICmpEQ(EA, C(0xFFu));
  Value *EBMaxM = B.CreateICmpEQ(EB, C(0xFFu));
  Value *MANonZeroM = B.CreateICmpNE(MARaw, C(0u));
  Value *MBNonZeroM = B.CreateICmpNE(MBRaw, C(0u));
  Value *AIsNaNM = B.CreateAnd(EAMaxM, MANonZeroM);
  Value *BIsNaNM = B.CreateAnd(EBMaxM, MBNonZeroM);
  Value *AIsInfM = B.CreateAnd(EAMaxM, B.CreateNot(MANonZeroM));
  Value *BIsInfM = B.CreateAnd(EBMaxM, B.CreateNot(MBNonZeroM));
  Value *ZeroTimesInf = B.CreateOr(B.CreateAnd(AIsZero, BIsInfM),
                                   B.CreateAnd(BIsZero, AIsInfM));
  Value *EitherNaNM = B.CreateOr(AIsNaNM, BIsNaNM);
  Value *NaNCaseM = B.CreateOr(EitherNaNM, ZeroTimesInf);
  Value *AnyInfM = B.CreateOr(AIsInfM, BIsInfM);
  Value *MulInfBits = B.CreateOr(SignField, C(0x7F800000u));

  Result = B.CreateSelect(AnyInfM, MulInfBits, Result);
  Result = B.CreateSelect(NaNCaseM, C(0x7FC00000u), Result);

  B.CreateRet(B.CreateBitCast(Result, F32));
}

// Stage 7g3 — IEEE-754 single-precision divide: `__divsf3 (a, b)`.
//
// Shape:
//   1. Extract sign / exp / mantissa from both inputs and OR in the
//      implicit-1 bit to get 24-bit ma / mb.
//   2. Initial normalize. The exact quotient ma/mb is in (1/2, 2);
//      if ma < mb we left-shift ma by 1 and decrement the result
//      exponent so the long-division loop starts with ma_norm in
//      `[mb, 2*mb)`. The first quotient bit is then implicitly 1
//      (the implicit-1 of the result mantissa), and the loop only
//      needs to grind out the remaining 23 fractional bits.
//   3. Long-division loop, 23 iterations:
//        r = ma_norm - mb        // [0, mb)
//        q = 1                   // implicit-1
//        for i in 23..1:
//          r <<= 1
//          q <<= 1
//          if r >= mb: r -= mb; q |= 1
//      After the loop q is the 24-bit mantissa with bit 23 = 1.
//   4. One more iter for the guard bit, then sticky = (residue != 0)
//      and round-to-nearest-ties-to-even. Rounding overflow bumps the
//      exponent by 1 and shifts q right by 1 (matches the existing
//      add / mul helpers).
//   5. Pack {sign = sa XOR sb, exp = ea - eb + 127 (- 1 if renorm,
//      + 1 if rounding overflow), mant}. Special cases:
//        - a == 0 (ea == 0)  → signed zero with sr
//        - b == 0 (eb == 0)  → signed Inf with sr
//        - ER overflow (>= 255) → signed Inf
//        - ER underflow (<= 0)  → signed zero
//      Inf / NaN propagation stays at the 7g1 best-effort level.
//
// Unlike the straight-line `__addsf3` / `__mulsf3` bodies, this
// helper uses a real loop with PHI nodes — exactly the same shape
// stage-7f2's `__udivsi3` uses for its 32-iter restoring division.
// The driver's SELECT → bit-blend rewrite still fires on the loop-
// body `select`s; the loop control itself (CondBr / PHI) survives
// into the lowered MIR. SDAG handles that without the multi-minute
// pathology that motivated the bit-blend rewrite, because the
// branching is now coarse (per-iteration, not per-arithmetic-op).
static void injectDivSf3Helper(Module &M, LLVMContext &Ctx) {
  Type *F32 = Type::getFloatTy(Ctx);
  Type *I32 = Type::getInt32Ty(Ctx);
  FunctionType *FnTy = FunctionType::get(F32, {F32, F32}, /*isVarArg=*/false);

  Function *F = makeOrPromoteHelper(M, "__divsf3", FnTy);
  if (!F)
    return;

  F->getArg(0)->setName("a");
  F->getArg(1)->setName("b");

  BasicBlock *Entry = BasicBlock::Create(Ctx, "entry", F);
  BasicBlock *Loop = BasicBlock::Create(Ctx, "loop", F);
  BasicBlock *Exit = BasicBlock::Create(Ctx, "exit", F);

  // === entry ===
  IRBuilder<> B(Entry);
  auto C = [&](uint32_t V) { return B.getInt32(V); };

  Value *AI = B.CreateBitCast(F->getArg(0), I32, "ai");
  Value *BI = B.CreateBitCast(F->getArg(1), I32, "bi");

  Value *SA = B.CreateLShr(AI, C(31), "sa");
  Value *SB = B.CreateLShr(BI, C(31), "sb");
  Value *EA = B.CreateAnd(B.CreateLShr(AI, C(23)), C(0xFFu), "ea");
  Value *EB = B.CreateAnd(B.CreateLShr(BI, C(23)), C(0xFFu), "eb");
  Value *MARaw = B.CreateAnd(AI, C(0x7FFFFFu), "ma_raw");
  Value *MBRaw = B.CreateAnd(BI, C(0x7FFFFFu), "mb_raw");

  Value *SR = B.CreateXor(SA, SB, "sr");

  // Special-case detection. Same flush-to-zero treatment of denormals
  // as the other 7g helpers (ex == 0 ⇒ value treated as zero).
  Value *AIsZero = B.CreateICmpEQ(EA, C(0u));
  Value *BIsZero = B.CreateICmpEQ(EB, C(0u));

  // Add the implicit-1 to each mantissa. Both ma and mb are now 24
  // bits, in `[2^23, 2^24)`.
  Value *MA = B.CreateOr(MARaw, C(0x800000u), "ma");
  Value *MB = B.CreateOr(MBRaw, C(0x800000u), "mb");

  // Initial renormalize: if ma < mb, the exact ma/mb is in (1/2, 1)
  // and we want to bring the implicit-1 of the result into the right
  // position. Shift ma left by 1 (so ma_norm in [mb, 2*mb)) and drop
  // ER by 1.
  Value *InitialRenorm = B.CreateICmpULT(MA, MB, "initial_renorm");
  Value *MANorm = B.CreateSelect(InitialRenorm, B.CreateShl(MA, C(1)), MA,
                                 "ma_norm");

  // Result exponent. ER = EA - EB + 127, adjusted by -1 if we
  // renormed.
  Value *ER0 = B.CreateAdd(B.CreateSub(EA, EB), C(127u));
  Value *ER = B.CreateSelect(InitialRenorm,
                             B.CreateSub(ER0, C(1u)), ER0, "er");

  // Initial loop state. ma_norm in [mb, 2*mb) ⇒ r0 = ma_norm - mb in
  // `[0, mb)` ⊂ `[0, 2^24)`. q0 = 1 represents the implicit-1 quotient
  // bit. The 23-iter loop fills in the remaining 23 fractional bits
  // (one per iteration); a final extra step in the exit block
  // produces the guard bit for round-to-nearest-ties-to-even.
  Value *R0 = B.CreateSub(MANorm, MB);
  Value *Q0 = C(1);

  B.CreateBr(Loop);

  // === loop ===
  B.SetInsertPoint(Loop);
  PHINode *IPhi = B.CreatePHI(I32, 2, "i");
  PHINode *RPhi = B.CreatePHI(I32, 2, "r");
  PHINode *QPhi = B.CreatePHI(I32, 2, "q");
  IPhi->addIncoming(C(23u), Entry);
  RPhi->addIncoming(R0, Entry);
  QPhi->addIncoming(Q0, Entry);

  Value *RShifted = B.CreateShl(RPhi, C(1));
  Value *QShifted = B.CreateShl(QPhi, C(1));
  Value *Take = B.CreateICmpUGE(RShifted, MB);
  Value *RSub = B.CreateSub(RShifted, MB);
  Value *QSet = B.CreateOr(QShifted, C(1));
  Value *RNext = B.CreateSelect(Take, RSub, RShifted);
  Value *QNext = B.CreateSelect(Take, QSet, QShifted);
  Value *INext = B.CreateSub(IPhi, C(1));
  // Loop control: continue while INext > 0. We start at i = 23 and
  // want 23 iterations total (i = 23, 22, …, 1 each running the body
  // once; after the iter where IPhi == 1 we hit INext == 0 and exit).
  Value *Done = B.CreateICmpEQ(INext, C(0));
  B.CreateCondBr(Done, Exit, Loop);
  IPhi->addIncoming(INext, Loop);
  RPhi->addIncoming(RNext, Loop);
  QPhi->addIncoming(QNext, Loop);

  // === exit ===
  B.SetInsertPoint(Exit);
  PHINode *RExit = B.CreatePHI(I32, 1, "r_out");
  PHINode *QExit = B.CreatePHI(I32, 1, "q_out");
  RExit->addIncoming(RNext, Loop);
  QExit->addIncoming(QNext, Loop);

  // Guard bit: one extra long-division step on the residue.
  Value *RGuardRaw = B.CreateShl(RExit, C(1));
  Value *GuardTake = B.CreateICmpUGE(RGuardRaw, MB);
  Value *GuardBit = B.CreateZExt(GuardTake, I32);
  Value *RAfterGuard = B.CreateSelect(GuardTake,
                                      B.CreateSub(RGuardRaw, MB),
                                      RGuardRaw);
  // Sticky: any leftover residue means at least one of the bits we
  // discarded was nonzero ⇒ "below halfway" rounding decision flips.
  Value *StickyI1 = B.CreateICmpNE(RAfterGuard, C(0));
  Value *Sticky = B.CreateZExt(StickyI1, I32);

  Value *Lsb = B.CreateAnd(QExit, C(1u));
  Value *RoundUp = B.CreateAnd(GuardBit, B.CreateOr(Sticky, Lsb));
  Value *QRounded = B.CreateAdd(QExit, RoundUp);
  Value *RoundOvf = B.CreateICmpEQ(QRounded, C(0x1000000u));
  Value *QFinal = B.CreateSelect(RoundOvf,
                                 B.CreateLShr(QRounded, C(1)),
                                 QRounded, "q_final");
  Value *ERFinal = B.CreateSelect(RoundOvf,
                                  B.CreateAdd(ER, C(1u)), ER, "er_final");

  // Pack.
  Value *MantField = B.CreateAnd(QFinal, C(0x7FFFFFu));
  Value *ExpField = B.CreateAnd(B.CreateShl(ERFinal, C(23)),
                                C(0x7F800000u));
  Value *SignField = B.CreateShl(SR, C(31));
  Value *Packed = B.CreateOr(SignField,
                             B.CreateOr(ExpField, MantField));

  // Result-exponent gates. ERFinal can wrap into the high i32 range
  // when underflowing, so use signed comparisons.
  Value *Underflow = B.CreateICmpSLE(ERFinal, C(0), "underflow");
  Value *Overflow = B.CreateICmpSGE(ERFinal, C(255), "overflow");
  Value *SignedZero = SignField;
  Value *SignedInf = B.CreateOr(SignField, C(0x7F800000u));

  Value *Result = B.CreateSelect(Overflow, SignedInf, Packed);
  Result = B.CreateSelect(Underflow, SignedZero, Result);
  // Input-zero gates first (a == 0, b == 0). With this ordering
  // divisor-zero wins over dividend-zero so `0.0 / 0.0` is signed
  // Inf at this point; the 7g4 NaN override below upgrades it to
  // NaN.
  Result = B.CreateSelect(AIsZero, SignedZero, Result);
  Result = B.CreateSelect(BIsZero, SignedInf, Result);

  // Stage 7g4 — Inf / NaN propagation overrides for fdiv:
  //   - NaN input             → canonical qNaN
  //   - Inf / Inf, 0 / 0      → NaN  (IEEE indeterminate)
  //   - Inf / finite (≠ 0)    → signed Inf with sr
  //   - finite / Inf          → signed zero with sr
  // Ordering: Inf-result / zero-result selects run first so they
  // override the loop-body's stale numbers; the NaN gate runs last
  // so 0/0 and Inf/Inf end up as NaN regardless of which way the
  // earlier gates set the bits.
  Value *EAMaxD = B.CreateICmpEQ(EA, C(0xFFu));
  Value *EBMaxD = B.CreateICmpEQ(EB, C(0xFFu));
  Value *MANonZeroD = B.CreateICmpNE(MARaw, C(0u));
  Value *MBNonZeroD = B.CreateICmpNE(MBRaw, C(0u));
  Value *AIsNaND = B.CreateAnd(EAMaxD, MANonZeroD);
  Value *BIsNaND = B.CreateAnd(EBMaxD, MBNonZeroD);
  Value *AIsInfD = B.CreateAnd(EAMaxD, B.CreateNot(MANonZeroD));
  Value *BIsInfD = B.CreateAnd(EBMaxD, B.CreateNot(MBNonZeroD));
  Value *BothInfD = B.CreateAnd(AIsInfD, BIsInfD);
  Value *BothZeroD = B.CreateAnd(AIsZero, BIsZero);
  Value *EitherNaND = B.CreateOr(AIsNaND, BIsNaND);
  Value *NaNCaseD = B.CreateOr(EitherNaND,
                               B.CreateOr(BothInfD, BothZeroD));

  // Inf / finite → signed Inf. "finite" here means !Inf && !NaN &&
  // (the divisor isn't itself zero, otherwise the 0-divisor gate
  // already routed us to Inf which is the same).
  Value *AInfBFinite = B.CreateAnd(AIsInfD,
                                   B.CreateNot(B.CreateOr(BIsInfD, BIsNaND)));
  // finite / Inf → signed zero. Mirror condition on the dividend.
  Value *BInfAFinite = B.CreateAnd(BIsInfD,
                                   B.CreateNot(B.CreateOr(AIsInfD, AIsNaND)));

  Result = B.CreateSelect(AInfBFinite, SignedInf, Result);
  Result = B.CreateSelect(BInfAFinite, SignedZero, Result);
  Result = B.CreateSelect(NaNCaseD, C(0x7FC00000u), Result);

  B.CreateRet(B.CreateBitCast(Result, F32));
}

// Stage 7g1 — IEEE-754 single-precision comparison helpers
// (`__eqsf2`, `__nesf2`, `__ltsf2`, `__lesf2`, `__gtsf2`, `__gesf2`,
// `__unordsf2`). The soft-float SDAG legalizer lowers each `fcmp
// <pred> float` into a libcall to one of these, then compares the
// returned i32 to zero with the predicate's expected sign.
//
// Compiler-rt semantics (compact summary; full table in libgcc /
// compiler-rt's `fp_lib.h`):
//
//   ordered, no NaN involved:
//     a == b → return  0
//     a <  b → return -1
//     a >  b → return +1
//
//   NaN involved (unordered):
//     __eqsf2, __nesf2, __ltsf2, __lesf2 → return +1
//     __gtsf2, __gesf2                    → return -1
//     __unordsf2                          → return 1 if either is NaN,
//                                           else 0
//
// All six ordered helpers share the same compare body, parameterised
// by the unord-return convention. We materialise each as its own
// definition so SDAG's symbol references resolve directly; the
// shared compare is just an inline IR sequence per helper (no
// internal call indirection).
static void emitFloatCompareBody(Function *F, LLVMContext &Ctx,
                                 int32_t UnordReturn) {
  Type *I32 = Type::getInt32Ty(Ctx);

  Argument *A = F->getArg(0); A->setName("a");
  Argument *B = F->getArg(1); B->setName("b");

  BasicBlock *Entry = BasicBlock::Create(Ctx, "entry", F);
  IRBuilder<> IR(Entry);
  auto C = [&](uint32_t V) { return IR.getInt32(V); };

  Value *AI = IR.CreateBitCast(A, I32, "ai");
  Value *BI = IR.CreateBitCast(B, I32, "bi");

  // Field extraction (only what we need for NaN detection + sign-
  // aware ordering).
  Value *SA = IR.CreateLShr(AI, C(31));
  Value *SB = IR.CreateLShr(BI, C(31));
  Value *EA = IR.CreateAnd(IR.CreateLShr(AI, C(23)), C(0xFFu));
  Value *EB = IR.CreateAnd(IR.CreateLShr(BI, C(23)), C(0xFFu));
  Value *MA = IR.CreateAnd(AI, C(0x7FFFFFu));
  Value *MB = IR.CreateAnd(BI, C(0x7FFFFFu));

  // NaN: exp == 0xFF AND mant != 0. Both bits.
  Value *AExpMax = IR.CreateICmpEQ(EA, C(0xFFu));
  Value *AMantNZ = IR.CreateICmpNE(MA, C(0));
  Value *ANaN = IR.CreateAnd(AExpMax, AMantNZ);
  Value *BExpMax = IR.CreateICmpEQ(EB, C(0xFFu));
  Value *BMantNZ = IR.CreateICmpNE(MB, C(0));
  Value *BNaN = IR.CreateAnd(BExpMax, BMantNZ);
  Value *Unord = IR.CreateOr(ANaN, BNaN);

  // Magnitude of each (sign-stripped i32).
  Value *AMag = IR.CreateAnd(AI, C(0x7FFFFFFFu));
  Value *BMag = IR.CreateAnd(BI, C(0x7FFFFFFFu));
  Value *BothZero = IR.CreateAnd(IR.CreateICmpEQ(AMag, C(0)),
                                 IR.CreateICmpEQ(BMag, C(0)));

  // Total-order trick: transform each bit pattern so signed-i32
  // compare matches float compare. For non-negatives keep the bits;
  // for negatives flip everything below the sign bit (`x XOR
  // 0x7FFFFFFF`). The transformed values then sort the same way
  // floats do, modulo the +0 / -0 distinction that we handle as
  // BothZero above.
  Value *SAMask = IR.CreateSub(C(0), SA);    // 0 or 0xFFFFFFFF (sign extend SA)
  Value *SBMask = IR.CreateSub(C(0), SB);
  Value *AKey = IR.CreateXor(AI, IR.CreateAnd(SAMask, C(0x7FFFFFFFu)));
  Value *BKey = IR.CreateXor(BI, IR.CreateAnd(SBMask, C(0x7FFFFFFFu)));

  // Ordered three-way compare on the keys (signed).
  Value *Lt = IR.CreateICmpSLT(AKey, BKey);
  Value *Gt = IR.CreateICmpSGT(AKey, BKey);
  // Ordered result: -1 / 0 / +1.
  Value *Pos1 = C(1);
  Value *Neg1 = C(0xFFFFFFFFu);   // = -1 as signed i32
  Value *Ord = IR.CreateSelect(Lt, Neg1,
                  IR.CreateSelect(Gt, Pos1, C(0)));
  Value *OrdWithZero = IR.CreateSelect(BothZero, C(0), Ord);

  // Unordered convention is helper-specific.
  Value *UnordRet = C(static_cast<uint32_t>(UnordReturn));
  Value *Result = IR.CreateSelect(Unord, UnordRet, OrdWithZero);
  IR.CreateRet(Result);
}

// Stage 7h2 — IEEE-754 double-precision comparison body. Mirrors the
// f32 `emitFloatCompareBody` but operates over the i64 bit pattern
// expressed as a {hi, lo} pair of i32 values. The pair representation
// keeps every op at i32 width, so the SELECT → bit-blend rewrite
// stays on its i32-only path — the body emits no `select i64`.
//
// Compiler-rt return convention (identical to the f32 helpers):
//   ordered, neither NaN:
//     a == b → return  0
//     a <  b → return -1
//     a >  b → return +1
//   unordered (either NaN):
//     __eqdf2 / __nedf2 / __ltdf2 / __ledf2 → return +1
//     __gtdf2 / __gedf2                      → return -1
static void emitDoubleCompareBody(Function *F, LLVMContext &Ctx,
                                  int32_t UnordReturn) {
  Type *I32 = Type::getInt32Ty(Ctx);
  Type *I64 = Type::getInt64Ty(Ctx);

  Argument *A = F->getArg(0); A->setName("a");
  Argument *B = F->getArg(1); B->setName("b");

  BasicBlock *Entry = BasicBlock::Create(Ctx, "entry", F);
  IRBuilder<> IR(Entry);
  auto C = [&](uint32_t V) { return IR.getInt32(V); };

  Value *AI64 = IR.CreateBitCast(A, I64, "ai64");
  Value *BI64 = IR.CreateBitCast(B, I64, "bi64");

  // Split each i64 into (lo, hi) i32 halves via constant-amount i64
  // lshr (the only i64 shift used here, lowers cleanly via SDAG's
  // i64-to-i32-pair type legalization).
  Value *AHi = IR.CreateTrunc(IR.CreateLShr(AI64, IR.getInt64(32)),
                              I32, "ai_hi");
  Value *ALo = IR.CreateTrunc(AI64, I32, "ai_lo");
  Value *BHi = IR.CreateTrunc(IR.CreateLShr(BI64, IR.getInt64(32)),
                              I32, "bi_hi");
  Value *BLo = IR.CreateTrunc(BI64, I32, "bi_lo");

  // Field extraction: hi[31] sign, hi[30..20] exp, hi[19..0] are the
  // top 20 mantissa bits; lo[31..0] are the remaining 32 mantissa
  // bits.
  Value *SA = IR.CreateLShr(AHi, C(31));
  Value *SB = IR.CreateLShr(BHi, C(31));
  Value *EA = IR.CreateAnd(IR.CreateLShr(AHi, C(20)), C(0x7FFu));
  Value *EB = IR.CreateAnd(IR.CreateLShr(BHi, C(20)), C(0x7FFu));
  Value *MAtop = IR.CreateAnd(AHi, C(0xFFFFFu));
  Value *MBtop = IR.CreateAnd(BHi, C(0xFFFFFu));

  // NaN: exp == 0x7FF AND (mant_top != 0 OR mant_bot != 0).
  Value *AExpMax = IR.CreateICmpEQ(EA, C(0x7FFu));
  Value *AMantNZ = IR.CreateOr(IR.CreateICmpNE(MAtop, C(0)),
                               IR.CreateICmpNE(ALo, C(0)));
  Value *ANaN = IR.CreateAnd(AExpMax, AMantNZ);
  Value *BExpMax = IR.CreateICmpEQ(EB, C(0x7FFu));
  Value *BMantNZ = IR.CreateOr(IR.CreateICmpNE(MBtop, C(0)),
                               IR.CreateICmpNE(BLo, C(0)));
  Value *BNaN = IR.CreateAnd(BExpMax, BMantNZ);
  Value *Unord = IR.CreateOr(ANaN, BNaN);

  // BothZero: magnitude (sign-stripped hi == 0 and lo == 0) on both
  // sides, so +0 / -0 compare equal.
  Value *AMagHi = IR.CreateAnd(AHi, C(0x7FFFFFFFu));
  Value *BMagHi = IR.CreateAnd(BHi, C(0x7FFFFFFFu));
  Value *AIsZero = IR.CreateAnd(IR.CreateICmpEQ(AMagHi, C(0)),
                                IR.CreateICmpEQ(ALo, C(0)));
  Value *BIsZero = IR.CreateAnd(IR.CreateICmpEQ(BMagHi, C(0)),
                                IR.CreateICmpEQ(BLo, C(0)));
  Value *BothZero = IR.CreateAnd(AIsZero, BIsZero);

  // Total-order key on each i32 half. For non-negatives keep the bits;
  // for negatives flip everything below the sign bit (hi) and every
  // bit in lo. Compute the sign mask as `0 - sign` (= 0 or 0xFFFFFFFF)
  // and apply it via AND-with-magnitude-mask on the hi half.
  Value *SAMask = IR.CreateSub(C(0), SA);
  Value *SBMask = IR.CreateSub(C(0), SB);
  Value *AKeyHi = IR.CreateXor(AHi, IR.CreateAnd(SAMask, C(0x7FFFFFFFu)));
  Value *BKeyHi = IR.CreateXor(BHi, IR.CreateAnd(SBMask, C(0x7FFFFFFFu)));
  Value *AKeyLo = IR.CreateXor(ALo, SAMask);
  Value *BKeyLo = IR.CreateXor(BLo, SBMask);

  // Ordered i64 compare via {signed hi, unsigned lo}:
  //   a < b  iff  (a.hi <s b.hi)  OR  (a.hi == b.hi AND a.lo <u b.lo)
  //   a > b  iff  (a.hi >s b.hi)  OR  (a.hi == b.hi AND a.lo >u b.lo)
  Value *HiSLt = IR.CreateICmpSLT(AKeyHi, BKeyHi);
  Value *HiSGt = IR.CreateICmpSGT(AKeyHi, BKeyHi);
  Value *HiEq  = IR.CreateICmpEQ(AKeyHi, BKeyHi);
  Value *LoULt = IR.CreateICmpULT(AKeyLo, BKeyLo);
  Value *LoUGt = IR.CreateICmpUGT(AKeyLo, BKeyLo);
  Value *Lt = IR.CreateOr(HiSLt, IR.CreateAnd(HiEq, LoULt));
  Value *Gt = IR.CreateOr(HiSGt, IR.CreateAnd(HiEq, LoUGt));

  // Ordered three-way result: -1 / 0 / +1.
  Value *Pos1 = C(1);
  Value *Neg1 = C(0xFFFFFFFFu);
  Value *Ord = IR.CreateSelect(Lt, Neg1,
                  IR.CreateSelect(Gt, Pos1, C(0)));
  Value *OrdWithZero = IR.CreateSelect(BothZero, C(0), Ord);

  // Unord-return convention is helper-specific (+1 for eq/ne/lt/le,
  // -1 for gt/ge).
  Value *UnordRet = C(static_cast<uint32_t>(UnordReturn));
  Value *Result = IR.CreateSelect(Unord, UnordRet, OrdWithZero);
  IR.CreateRet(Result);
}

static void injectDoubleCompareHelpers(Module &M, LLVMContext &Ctx) {
  Type *F64 = Type::getDoubleTy(Ctx);
  Type *I32 = Type::getInt32Ty(Ctx);
  Type *I64 = Type::getInt64Ty(Ctx);
  FunctionType *FnTy = FunctionType::get(I32, {F64, F64}, /*isVarArg=*/false);

  struct HelperSpec {
    const char *Name;
    int32_t UnordReturn;
  };
  static const HelperSpec Specs[] = {
      {"__eqdf2", +1}, {"__nedf2", +1}, {"__ltdf2", +1}, {"__ledf2", +1},
      {"__gtdf2", -1}, {"__gedf2", -1},
  };
  for (const auto &S : Specs) {
    Function *F = makeOrPromoteHelper(M, S.Name, FnTy);
    if (F)
      emitDoubleCompareBody(F, Ctx, S.UnordReturn);
  }

  // __unorddf2 — returns 1 if either argument is NaN, 0 otherwise.
  Function *UnordDf = makeOrPromoteHelper(M, "__unorddf2", FnTy);
  if (UnordDf) {
    Argument *A = UnordDf->getArg(0); A->setName("a");
    Argument *B = UnordDf->getArg(1); B->setName("b");
    BasicBlock *BB = BasicBlock::Create(Ctx, "entry", UnordDf);
    IRBuilder<> IR(BB);
    auto C = [&](uint32_t V) { return IR.getInt32(V); };
    Value *AI64 = IR.CreateBitCast(A, I64);
    Value *BI64 = IR.CreateBitCast(B, I64);
    Value *AHi = IR.CreateTrunc(IR.CreateLShr(AI64, IR.getInt64(32)), I32);
    Value *ALo = IR.CreateTrunc(AI64, I32);
    Value *BHi = IR.CreateTrunc(IR.CreateLShr(BI64, IR.getInt64(32)), I32);
    Value *BLo = IR.CreateTrunc(BI64, I32);
    Value *EA = IR.CreateAnd(IR.CreateLShr(AHi, C(20)), C(0x7FFu));
    Value *EB = IR.CreateAnd(IR.CreateLShr(BHi, C(20)), C(0x7FFu));
    Value *MAtop = IR.CreateAnd(AHi, C(0xFFFFFu));
    Value *MBtop = IR.CreateAnd(BHi, C(0xFFFFFu));
    Value *AMantNZ = IR.CreateOr(IR.CreateICmpNE(MAtop, C(0)),
                                 IR.CreateICmpNE(ALo, C(0)));
    Value *BMantNZ = IR.CreateOr(IR.CreateICmpNE(MBtop, C(0)),
                                 IR.CreateICmpNE(BLo, C(0)));
    Value *ANaN = IR.CreateAnd(IR.CreateICmpEQ(EA, C(0x7FFu)), AMantNZ);
    Value *BNaN = IR.CreateAnd(IR.CreateICmpEQ(EB, C(0x7FFu)), BMantNZ);
    Value *Unord = IR.CreateOr(ANaN, BNaN);
    IR.CreateRet(IR.CreateZExt(Unord, I32));
  }
}

static void injectFloatCompareHelpers(Module &M, LLVMContext &Ctx) {
  Type *F32 = Type::getFloatTy(Ctx);
  Type *I32 = Type::getInt32Ty(Ctx);
  FunctionType *FnTy = FunctionType::get(I32, {F32, F32}, /*isVarArg=*/false);

  struct HelperSpec {
    const char *Name;
    int32_t UnordReturn;
  };
  // The "pos unord" group (eq, ne, lt, le) returns +1 when either
  // operand is NaN — that makes `result == 0` mean "ordered and
  // equal", `result < 0` mean "ordered and a < b", and `result > 0`
  // mean "ordered and a > b OR unordered". The "neg unord" group
  // (gt, ge) flips the unord sign.
  static const HelperSpec Specs[] = {
      {"__eqsf2", +1}, {"__nesf2", +1}, {"__ltsf2", +1}, {"__lesf2", +1},
      {"__gtsf2", -1}, {"__gesf2", -1},
  };
  for (const auto &S : Specs) {
    Function *F = makeOrPromoteHelper(M, S.Name, FnTy);
    if (F)
      emitFloatCompareBody(F, Ctx, S.UnordReturn);
  }

  // __unordsf2 — returns 1 if either argument is NaN, 0 otherwise.
  Function *UnordSf = makeOrPromoteHelper(M, "__unordsf2", FnTy);
  if (UnordSf) {
    Argument *A = UnordSf->getArg(0); A->setName("a");
    Argument *B = UnordSf->getArg(1); B->setName("b");
    BasicBlock *BB = BasicBlock::Create(Ctx, "entry", UnordSf);
    IRBuilder<> IR(BB);
    auto C = [&](uint32_t V) { return IR.getInt32(V); };
    Value *AI = IR.CreateBitCast(A, I32);
    Value *BI = IR.CreateBitCast(B, I32);
    Value *EA = IR.CreateAnd(IR.CreateLShr(AI, C(23)), C(0xFFu));
    Value *EB = IR.CreateAnd(IR.CreateLShr(BI, C(23)), C(0xFFu));
    Value *MA = IR.CreateAnd(AI, C(0x7FFFFFu));
    Value *MB = IR.CreateAnd(BI, C(0x7FFFFFu));
    Value *ANaN = IR.CreateAnd(IR.CreateICmpEQ(EA, C(0xFFu)),
                               IR.CreateICmpNE(MA, C(0)));
    Value *BNaN = IR.CreateAnd(IR.CreateICmpEQ(EB, C(0xFFu)),
                               IR.CreateICmpNE(MB, C(0)));
    Value *Unord = IR.CreateOr(ANaN, BNaN);
    IR.CreateRet(IR.CreateZExt(Unord, I32));
  }
}

// Stage 7g1 — `__floatsisf` and `__floatunsisf`: i32/u32 → f32.
// Algorithm:
//   - if value == 0: return +0.0
//   - sign = (signed only) value < 0 ? 1 : 0
//   - mag = signed: (value < 0) ? -value (as u32) : value
//                   unsigned: value
//   - lz = ctlz(mag)  // 0..31 for non-zero mag
//   - hi = 31 - lz    // position of the leading 1
//   - exp = hi + 127  (biased)
//   - mantissa = mag shifted to put `hi` at bit 23, rounded with
//                guard / round / sticky
//   - pack (sign << 31) | (exp << 23) | (mant & 0x7FFFFF)
//
// Rounding follows the round-nearest-ties-to-even convention. The
// guard / round / sticky bits live in the low bits when hi > 23
// (i.e. precision is lost during conversion); when hi ≤ 23 the
// result is exact.
static void emitInt32ToFloatBody(Function *F, LLVMContext &Ctx,
                                 Module &M, bool IsSigned) {
  Type *I32 = Type::getInt32Ty(Ctx);
  Type *F32 = Type::getFloatTy(Ctx);

  Argument *V = F->getArg(0); V->setName("v");
  BasicBlock *BB = BasicBlock::Create(Ctx, "entry", F);
  IRBuilder<> B(BB);
  auto C = [&](uint32_t X) { return B.getInt32(X); };

  Value *Sign;
  Value *Mag;
  if (IsSigned) {
    // Sign = (v < 0). Magnitude is the absolute value, treating
    // INT_MIN as 0x80000000 (wraps cleanly under unsigned negate).
    Value *Neg = B.CreateICmpSLT(V, C(0));
    Sign = B.CreateZExt(Neg, I32);
    Value *VNeg = B.CreateSub(C(0), V);
    Mag = B.CreateSelect(Neg, VNeg, V);
  } else {
    Sign = C(0);
    Mag = V;
  }

  // Zero shortcut — handled via a final select to keep the helper
  // straight-line.
  Value *IsZero = B.CreateICmpEQ(Mag, C(0));

  Function *Ctlz =
      Intrinsic::getOrInsertDeclaration(&M, Intrinsic::ctlz, {I32});
  Value *LZ = B.CreateCall(Ctlz, {Mag, ConstantInt::getFalse(Ctx)}, "lz");
  Value *Hi = B.CreateSub(C(31), LZ);                    // 0..31
  Value *ExpBiased = B.CreateAdd(Hi, C(127u));
  Value *HiGt23 = B.CreateICmpUGT(Hi, C(23u));

  // Lossless shift left when hi ≤ 23. Clamping `LeftShift` to keep
  // the shift in [0, 31] even when the other path (Hi > 23) makes
  // `23 - Hi` wrap as unsigned — the driver's SELECT → bit-blend
  // rewrite evaluates both arms, so an out-of-range shift becomes
  // poison that can propagate through the bit-blend mask. Codex-
  // review P1.
  Value *LeftShiftRaw = B.CreateSub(C(23u), Hi);
  Value *LeftShift = B.CreateSelect(HiGt23, C(0u), LeftShiftRaw);
  Value *LeftPath = B.CreateShl(Mag, LeftShift);

  // Lossy shift right when hi > 23. Need guard / round / sticky for
  // round-to-nearest-ties-to-even. When Hi ≤ 23 we force the right-
  // path quantities to a safe minimum (Shift = 1) so the LShr and
  // the `Shift - 1` for `Halfway` both stay in i32-shift range; the
  // computed values are unused (the outer select picks LeftPath
  // instead), but the bit-blend still needs them to be well-defined.
  Value *ShiftRaw = B.CreateSub(Hi, C(23u));
  Value *Shift = B.CreateSelect(HiGt23, ShiftRaw, C(1u));
  Value *MantTrunc = B.CreateLShr(Mag, Shift);            // 24 bits
  // Bits we're about to lose:
  //   discarded[shift-1] = guard
  //   discarded[shift-2] = round
  //   discarded[0..shift-3] OR ⇒ sticky
  // Compute these branchlessly: the lost mask covers low `shift` bits
  // of Mag.
  // Build "lost = Mag - (MantTrunc << Shift)" instead of `mask = (1 <<
  // shift) - 1` to avoid the shift-by-32 hazard if Shift could be 32
  // (it can't here, but the same primitive is reused below).
  Value *LostMask = B.CreateSub(Mag, B.CreateShl(MantTrunc, Shift));
  Value *Halfway = B.CreateShl(C(1), B.CreateSub(Shift, C(1)));
  Value *Above = B.CreateICmpUGT(LostMask, Halfway);
  Value *Tie = B.CreateICmpEQ(LostMask, Halfway);
  Value *LsbSet = B.CreateICmpNE(B.CreateAnd(MantTrunc, C(1)), C(0));
  Value *RoundUp = B.CreateOr(Above, B.CreateAnd(Tie, LsbSet));
  Value *MantRounded = B.CreateAdd(MantTrunc,
                                   B.CreateZExt(RoundUp, I32));
  // Rounding may push mantissa to 0x1000000, requiring exponent +1.
  Value *RoundOvf = B.CreateICmpEQ(MantRounded, C(0x1000000u));
  Value *MantFinal = B.CreateSelect(RoundOvf,
                                    B.CreateLShr(MantRounded, C(1)),
                                    MantRounded);
  Value *ExpRight = B.CreateSelect(RoundOvf, B.CreateAdd(ExpBiased, C(1u)),
                                   ExpBiased);
  Value *RightPath = MantFinal;
  // We're going to pack later, so the "value to pack" must be the
  // 24-bit mantissa (rounded for hi > 23, left-shifted for hi ≤ 23).
  // `HiGt23` was computed at the top of the body so the shift counts
  // for both arms could be clamped before evaluating either; reuse
  // it here as the pack-selector.
  Value *MantForPack = B.CreateSelect(HiGt23, RightPath, LeftPath);
  Value *ExpForPack  = B.CreateSelect(HiGt23, ExpRight, ExpBiased);

  Value *MantField = B.CreateAnd(MantForPack, C(0x7FFFFFu));
  Value *ExpField  = B.CreateAnd(B.CreateShl(ExpForPack, C(23)),
                                 C(0x7F800000u));
  Value *SignField = B.CreateShl(Sign, C(31));
  Value *Packed = B.CreateOr(SignField, B.CreateOr(ExpField, MantField));
  Value *Result = B.CreateSelect(IsZero, C(0), Packed);
  B.CreateRet(B.CreateBitCast(Result, F32));
}

static void injectFloatsisfHelpers(Module &M, LLVMContext &Ctx) {
  Type *I32 = Type::getInt32Ty(Ctx);
  Type *F32 = Type::getFloatTy(Ctx);
  FunctionType *FnTy = FunctionType::get(F32, {I32}, /*isVarArg=*/false);
  if (Function *F = makeOrPromoteHelper(M, "__floatsisf", FnTy))
    emitInt32ToFloatBody(F, Ctx, M, /*IsSigned=*/true);
  if (Function *F = makeOrPromoteHelper(M, "__floatunsisf", FnTy))
    emitInt32ToFloatBody(F, Ctx, M, /*IsSigned=*/false);
}

// Stage 7g1 — `__fixsfsi` and `__fixunssfsi`: f32 → i32/u32 (truncate
// toward zero). Algorithm:
//   - if exp < 127: |f| < 1, result = 0
//   - if exp >= 158 (signed) / 159 (unsigned): out-of-range,
//     saturate to INT_MIN/MAX or UINT_MAX
//   - mantissa = mantissa_raw | 0x800000
//   - shift = exp - 23 - 127
//   - if shift >= 0: integer = mantissa << shift
//     else (shift < 0): integer = mantissa >> (-shift)
//   - if signed and original sign was negative: integer = -integer
static void emitFloatToInt32Body(Function *F, LLVMContext &Ctx,
                                 bool IsSigned) {
  Type *I32 = Type::getInt32Ty(Ctx);

  Argument *V = F->getArg(0); V->setName("f");
  BasicBlock *BB = BasicBlock::Create(Ctx, "entry", F);
  IRBuilder<> B(BB);
  auto C = [&](uint32_t X) { return B.getInt32(X); };

  Value *VI = B.CreateBitCast(V, I32);
  Value *Sign = B.CreateLShr(VI, C(31));
  Value *Exp = B.CreateAnd(B.CreateLShr(VI, C(23)), C(0xFFu));
  Value *Mant = B.CreateOr(B.CreateAnd(VI, C(0x7FFFFFu)), C(0x800000u));

  // Underflow: exp < 127 ⇒ |f| < 1 ⇒ truncate to 0.
  Value *Underflow = B.CreateICmpULT(Exp, C(127u));

  // Compute shift = exp - 150 (= exp - 127 - 23). Positive shift
  // means left-shift; negative means right-shift.
  Value *Shift = B.CreateSub(Exp, C(150u));
  Value *NeedLeft = B.CreateICmpUGT(Exp, C(150u));
  Value *NeedRight = B.CreateICmpULT(Exp, C(150u));
  Value *RightAmt = B.CreateSub(C(150u), Exp);
  // Cap right-shift at 31 to keep the lshr defined; values with
  // exp < 127 are already gated by `Underflow` and overwritten with
  // zero at the end, but the lshr's argument is still computed in the
  // straight-line body.
  Value *RightAmtClamped = B.CreateSelect(
      B.CreateICmpULT(RightAmt, C(31u)), RightAmt, C(31u));
  // Cap left-shift at 31 too. Out-of-range values (exp ≥ 158/159)
  // route through saturation below.
  Value *LeftAmt = B.CreateSelect(NeedLeft, Shift, C(0u));
  Value *LeftAmtClamped = B.CreateSelect(
      B.CreateICmpULT(LeftAmt, C(31u)), LeftAmt, C(31u));
  Value *LeftPath = B.CreateShl(Mant, LeftAmtClamped);
  Value *RightPath = B.CreateLShr(Mant, RightAmtClamped);
  Value *ShiftedNoSign = B.CreateSelect(NeedRight, RightPath,
                                        B.CreateSelect(NeedLeft, LeftPath, Mant));

  // Apply sign for signed conversion.
  Value *Result;
  if (IsSigned) {
    Value *Neg = B.CreateICmpEQ(Sign, C(1));
    Value *NegResult = B.CreateSub(C(0), ShiftedNoSign);
    Result = B.CreateSelect(Neg, NegResult, ShiftedNoSign);

    // Saturation: exp >= 158 ⇒ |result| ≥ 2^31 ⇒ saturate.
    // Special case: -2^31 = INT_MIN fits exactly (exp 158, mant
    // 0x800000, sign 1), but |INT_MIN| as a positive float overflows.
    Value *ExpGe158 = B.CreateICmpUGE(Exp, C(158u));
    Value *PosSat = C(0x7FFFFFFFu);                 // INT_MAX
    Value *NegSat = C(0x80000000u);                 // INT_MIN
    Value *Sat = B.CreateSelect(Neg, NegSat, PosSat);
    Result = B.CreateSelect(ExpGe158, Sat, Result);
  } else {
    Result = ShiftedNoSign;
    // Unsigned: positive overflow (|f| ≥ 2^32) → UINT_MAX, negative
    // inputs → 0. Order matters (codex-review P2): if we apply the
    // "negative → 0" gate first and then the "overflow → UINT_MAX"
    // gate, a large negative number (e.g. `fptoui -4294967296.0`)
    // would hit both gates in sequence and end up at UINT_MAX. The
    // overflow saturation must therefore be conditioned on the
    // positive sign, and the negative clamp comes last.
    Value *NegSign = B.CreateICmpEQ(Sign, C(1));
    Value *ExpGe159 = B.CreateICmpUGE(Exp, C(159u));
    Value *PosOverflow = B.CreateAnd(B.CreateNot(NegSign), ExpGe159);
    Result = B.CreateSelect(PosOverflow, C(0xFFFFFFFFu), Result);
    Result = B.CreateSelect(NegSign, C(0), Result);
  }

  // Final underflow gate.
  Result = B.CreateSelect(Underflow, C(0), Result);
  // Stage 7h8 — NaN → 0 (matches the `llvm.fptosi.sat` /
  // `llvm.fptoui.sat` convention so Custom-lowering them to plain
  // FP_TO_SINT / FP_TO_UINT preserves the saturating semantics).
  // NaN: exp == 0xFF AND mant != 0.
  Value *ExpIsMaxF = B.CreateICmpEQ(Exp, C(0xFFu));
  Value *MantNZF = B.CreateICmpNE(B.CreateAnd(VI, C(0x7FFFFFu)), C(0u));
  Value *IsNaNF = B.CreateAnd(ExpIsMaxF, MantNZF);
  Result = B.CreateSelect(IsNaNF, C(0), Result);
  B.CreateRet(Result);
}

static void injectFixsfsiHelpers(Module &M, LLVMContext &Ctx) {
  Type *I32 = Type::getInt32Ty(Ctx);
  Type *F32 = Type::getFloatTy(Ctx);
  FunctionType *FnTy = FunctionType::get(I32, {F32}, /*isVarArg=*/false);
  if (Function *F = makeOrPromoteHelper(M, "__fixsfsi", FnTy))
    emitFloatToInt32Body(F, Ctx, /*IsSigned=*/true);
  if (Function *F = makeOrPromoteHelper(M, "__fixunssfsi", FnTy))
    emitFloatToInt32Body(F, Ctx, /*IsSigned=*/false);
}

// Stage 7h3 — `__floatsidf (i32) -> f64` / `__floatunsidf (u32) -> f64`.
// Always-exact conversion (i32's 32 bits fit in f64's 53-bit mantissa
// without loss). Algorithm:
//   - if v == 0: return +0.0
//   - sign / mag = (signed) sign + abs; (unsigned) 0 + v
//   - lz = ctlz(mag), hi = 31 - lz                    (0..31)
//   - exp_biased = hi + 1023                          (1023..1054)
//   - shift = 52 - hi                                 (21..52)
//
//   Position the leading 1 of mag at bit 52 of the i64 mantissa.
//   Split into two arms by whether `shift < 32`:
//     small arm (21..31):
//       mant64_hi = mag >> (32 - shift)     (1..11 right-shift)
//       mant64_lo = mag << shift            (21..31 left-shift)
//     big arm (32..52):
//       mant64_hi = mag << (shift - 32)     (0..20 left-shift)
//       mant64_lo = 0
//
//   Drop the implicit-1 at bit 52 (= bit 20 of mant64_hi) when
//   packing; pack {sign, exp_biased, mant_hi[19:0]} into i32 hi half
//   and `mant_lo` into i32 lo half.
//
// All variable shifts are i32-typed with amounts clamped to [0, 31]
// so the SELECT → bit-blend rewrite's "evaluate both arms" semantics
// stays defined regardless of which arm is finally selected. The i64
// recombination at the end uses only constant-amount shifts.
static void emitInt32ToDoubleBody(Function *F, LLVMContext &Ctx,
                                  Module &M, bool IsSigned) {
  Type *I32 = Type::getInt32Ty(Ctx);
  Type *I64 = Type::getInt64Ty(Ctx);
  Type *F64 = Type::getDoubleTy(Ctx);

  Argument *V = F->getArg(0); V->setName("v");
  BasicBlock *BB = BasicBlock::Create(Ctx, "entry", F);
  IRBuilder<> B(BB);
  auto C = [&](uint32_t X) { return B.getInt32(X); };

  Value *Sign;
  Value *Mag;
  if (IsSigned) {
    Value *Neg = B.CreateICmpSLT(V, C(0));
    Sign = B.CreateZExt(Neg, I32);
    Value *VNeg = B.CreateSub(C(0), V);
    Mag = B.CreateSelect(Neg, VNeg, V);
  } else {
    Sign = C(0);
    Mag = V;
  }

  Value *IsZero = B.CreateICmpEQ(Mag, C(0));

  Function *Ctlz =
      Intrinsic::getOrInsertDeclaration(&M, Intrinsic::ctlz, {I32});
  Value *LZ = B.CreateCall(Ctlz, {Mag, ConstantInt::getFalse(Ctx)}, "lz");
  Value *Hi = B.CreateSub(C(31), LZ);
  Value *ExpBiased = B.CreateAdd(Hi, C(1023u));

  // Shift to put leading 1 at bit 52 of mantissa.
  Value *Shift = B.CreateSub(C(52u), Hi);
  Value *Small = B.CreateICmpULT(Shift, C(32u));

  // Small-arm clamped shifts: when not chosen, the shift amounts are
  // bogus; force them into a defined range so the materialised arm
  // doesn't introduce undefined-shift poison through the bit-blend.
  Value *SmallShiftL = B.CreateSelect(Small, Shift, C(0u));
  Value *SmallShiftR = B.CreateSelect(Small, B.CreateSub(C(32u), Shift),
                                      C(1u));
  Value *MantHiSmall = B.CreateLShr(Mag, SmallShiftR);
  Value *MantLoSmall = B.CreateShl(Mag, SmallShiftL);

  // Big-arm clamped shift.
  Value *BigShiftL = B.CreateSelect(Small, C(0u),
                                    B.CreateSub(Shift, C(32u)));
  Value *MantHiBig = B.CreateShl(Mag, BigShiftL);
  Value *MantLoBig = C(0);

  Value *MantHi = B.CreateSelect(Small, MantHiSmall, MantHiBig);
  Value *MantLo = B.CreateSelect(Small, MantLoSmall, MantLoBig);

  // Pack: drop bit 52 (= bit 20 of MantHi, the implicit 1).
  Value *MantHiField = B.CreateAnd(MantHi, C(0xFFFFFu));
  Value *ExpField = B.CreateAnd(B.CreateShl(ExpBiased, C(20)),
                                C(0x7FF00000u));
  Value *SignField = B.CreateShl(Sign, C(31));
  Value *PackHi = B.CreateOr(SignField,
                             B.CreateOr(ExpField, MantHiField));
  Value *PackLo = MantLo;

  // Zero override on both halves.
  Value *FinalHi = B.CreateSelect(IsZero, C(0), PackHi);
  Value *FinalLo = B.CreateSelect(IsZero, C(0), PackLo);

  // Combine to i64 via constant-amount shifts.
  Value *Result64 = B.CreateOr(
      B.CreateShl(B.CreateZExt(FinalHi, I64), B.getInt64(32)),
      B.CreateZExt(FinalLo, I64));
  B.CreateRet(B.CreateBitCast(Result64, F64));
}

static void injectFloatsidfHelpers(Module &M, LLVMContext &Ctx) {
  Type *I32 = Type::getInt32Ty(Ctx);
  Type *F64 = Type::getDoubleTy(Ctx);
  FunctionType *FnTy = FunctionType::get(F64, {I32}, /*isVarArg=*/false);
  if (Function *F = makeOrPromoteHelper(M, "__floatsidf", FnTy))
    emitInt32ToDoubleBody(F, Ctx, M, /*IsSigned=*/true);
  if (Function *F = makeOrPromoteHelper(M, "__floatunsidf", FnTy))
    emitInt32ToDoubleBody(F, Ctx, M, /*IsSigned=*/false);
}

// Stage 7h3 — `__fixdfsi (f64) -> i32` / `__fixunsdfsi (f64) -> u32`.
// f64 → i32 truncate-toward-zero with explicit saturation outside
// the i32 range.
//
//   exp < 1023                 ⇒ |d| < 1                   ⇒ 0
//   exp ∈ [1023, 1053]         ⇒ |d| ∈ [1, 2^31)            ⇒ shift
//   exp ≥ 1054 (signed)        ⇒ |d| ≥ 2^31                 ⇒ saturate to
//                                                            INT_MIN/MAX
//   exp ≥ 1055 (unsigned)      ⇒ |d| ≥ 2^32                 ⇒ UINT_MAX
//
// For the in-range case, the 53-bit mantissa is right-shifted by
// `1075 - exp` (range 22..52) to extract the integer part. Split
// across i32 halves:
//   if shift_right ≥ 32 (exp ≤ 1043):
//     result = full_mant_hi >> (shift_right - 32)
//   else:
//     result = (full_mant_lo >> shift_right) | (full_mant_hi << (32 - shift_right))
static void emitDoubleToInt32Body(Function *F, LLVMContext &Ctx,
                                  bool IsSigned) {
  Type *I32 = Type::getInt32Ty(Ctx);
  Type *I64 = Type::getInt64Ty(Ctx);

  Argument *V = F->getArg(0); V->setName("d");
  BasicBlock *BB = BasicBlock::Create(Ctx, "entry", F);
  IRBuilder<> B(BB);
  auto C = [&](uint32_t X) { return B.getInt32(X); };

  Value *DI64 = B.CreateBitCast(V, I64);
  Value *DHi = B.CreateTrunc(B.CreateLShr(DI64, B.getInt64(32)),
                             I32, "d_hi");
  Value *DLo = B.CreateTrunc(DI64, I32, "d_lo");

  Value *Sign = B.CreateLShr(DHi, C(31));
  Value *Exp = B.CreateAnd(B.CreateLShr(DHi, C(20)), C(0x7FFu));
  Value *MantTop = B.CreateAnd(DHi, C(0xFFFFFu));    // 20 bits
  Value *MantBot = DLo;                              // 32 bits

  // 53-bit mantissa with implicit 1.
  Value *FullMantHi = B.CreateOr(MantTop, C(0x100000u));
  Value *FullMantLo = MantBot;

  // Underflow.
  Value *Underflow = B.CreateICmpULT(Exp, C(1023u));

  Value *ShiftR = B.CreateSub(C(1075u), Exp);  // wants 22..52
  Value *ShiftRGe32 = B.CreateICmpUGE(ShiftR, C(32u));

  // Codex-review P1: `Exp` can be any value in [0, 2047] because we
  // accept arbitrary f64 inputs (zero, denormal, Inf, NaN, …); only
  // the [1023, 1053] window has a well-defined ShiftR in [22, 52].
  // Outside that window the bit-blended unused arm would compute a
  // poison shift (e.g. ShiftR = 1075 for f64 = 0.0). The later
  // Underflow / Overflow gates override Result correctly, but the
  // shifts themselves still have to be defined. Clamp every shift
  // count to ≤ 31 so each `lshr` / `shl` is well-defined regardless
  // of input.
  auto ClampTo31 = [&](Value *X) {
    return B.CreateSelect(B.CreateICmpUGT(X, C(31u)), C(31u), X);
  };

  // Big arm (shift_right ≥ 32): result comes from FullMantHi alone.
  Value *BigShift = ClampTo31(B.CreateSelect(
      ShiftRGe32, B.CreateSub(ShiftR, C(32u)), C(0u)));
  Value *BigPath = B.CreateLShr(FullMantHi, BigShift);

  // Small arm (shift_right < 32): combine both halves.
  Value *SmallShiftR = ClampTo31(
      B.CreateSelect(ShiftRGe32, C(1u), ShiftR));
  Value *SmallShiftL = ClampTo31(B.CreateSelect(
      ShiftRGe32, C(0u), B.CreateSub(C(32u), ShiftR)));
  Value *SmallPath = B.CreateOr(B.CreateLShr(FullMantLo, SmallShiftR),
                                B.CreateShl(FullMantHi, SmallShiftL));

  Value *MagPath = B.CreateSelect(ShiftRGe32, BigPath, SmallPath);

  Value *Result;
  if (IsSigned) {
    Value *NegSign = B.CreateICmpEQ(Sign, C(1));
    Value *NegMag = B.CreateSub(C(0), MagPath);
    Result = B.CreateSelect(NegSign, NegMag, MagPath);

    // Saturate when |d| ≥ 2^31. exp == 1054 with sign == 1 and
    // mant == 0 is exactly INT_MIN; the saturation lands on the
    // same value, so no special-case needed.
    Value *ExpGe1054 = B.CreateICmpUGE(Exp, C(1054u));
    Value *PosSat = C(0x7FFFFFFFu);
    Value *NegSat = C(0x80000000u);
    Value *Sat = B.CreateSelect(NegSign, NegSat, PosSat);
    Result = B.CreateSelect(ExpGe1054, Sat, Result);
  } else {
    Result = MagPath;
    Value *NegSign = B.CreateICmpEQ(Sign, C(1));
    Value *ExpGe1055 = B.CreateICmpUGE(Exp, C(1055u));
    Value *PosOverflow = B.CreateAnd(B.CreateNot(NegSign), ExpGe1055);
    Result = B.CreateSelect(PosOverflow, C(0xFFFFFFFFu), Result);
    Result = B.CreateSelect(NegSign, C(0), Result);
  }

  Result = B.CreateSelect(Underflow, C(0), Result);
  // Stage 7h8 — NaN → 0 (matches `llvm.fptosi.sat` / `llvm.fptoui.
  // sat` convention; lets MovISelLowering's Custom lowering re-emit
  // these intrinsics as plain FP_TO_SINT / FP_TO_UINT without
  // breaking the NaN→0 semantics). NaN: exp == 0x7FF AND mant
  // (top OR bot) != 0.
  Value *ExpIsMaxD = B.CreateICmpEQ(Exp, C(0x7FFu));
  Value *MantNZD = B.CreateOr(B.CreateICmpNE(MantTop, C(0u)),
                              B.CreateICmpNE(MantBot, C(0u)));
  Value *IsNaND = B.CreateAnd(ExpIsMaxD, MantNZD);
  Result = B.CreateSelect(IsNaND, C(0), Result);
  B.CreateRet(Result);
}

static void injectFixdfsiHelpers(Module &M, LLVMContext &Ctx) {
  Type *I32 = Type::getInt32Ty(Ctx);
  Type *F64 = Type::getDoubleTy(Ctx);
  FunctionType *FnTy = FunctionType::get(I32, {F64}, /*isVarArg=*/false);
  if (Function *F = makeOrPromoteHelper(M, "__fixdfsi", FnTy))
    emitDoubleToInt32Body(F, Ctx, /*IsSigned=*/true);
  if (Function *F = makeOrPromoteHelper(M, "__fixunsdfsi", FnTy))
    emitDoubleToInt32Body(F, Ctx, /*IsSigned=*/false);
}

// Stage 7h9 — `__floatdidf (i64) -> f64` / `__floatundidf (u64) -> f64`.
// Conversion is lossless for |v| ≤ 2^53; values above that bound
// round to nearest, ties to even (RNTE).
//
// Algorithm:
//   - if v == 0: return +0.0
//   - sign / mag = (signed) sign + i64 abs ; (unsigned) 0 + v
//   - lz = ctlz_i64(mag) ; hi = 63 - lz                (0..63)
//   - exp_biased = hi + 1023                          (1023..1086)
//   - if hi ≤ 52: shift left by (52 - hi)              (lossless)
//   - else: shift right by (hi - 52) with RNTE rounding
//   - mantissa-overflow ⇒ shift right 1 and exp += 1
//   - pack {sign, exp, mant[51:0]}
//
// Variable i64 shifts go through `emitLshrI64ByI32` /
// `emitShlI64ByI32` (stage 7h4 utilities). The amounts are bounded
// by 52, so the clamped-arm split stays well-defined.
static void emitInt64ToDoubleBody(Function *F, LLVMContext &Ctx,
                                  Module &M, bool IsSigned) {
  Type *I32 = Type::getInt32Ty(Ctx);
  Type *I64 = Type::getInt64Ty(Ctx);
  Type *F64 = Type::getDoubleTy(Ctx);

  Argument *V = F->getArg(0); V->setName("v");
  BasicBlock *BB = BasicBlock::Create(Ctx, "entry", F);
  IRBuilder<> B(BB);
  auto C32 = [&](uint32_t X) { return B.getInt32(X); };
  auto C64 = [&](uint64_t X) { return ConstantInt::get(I64, X); };

  // Lambdas mirroring the f64 fadd/fdiv helpers so i64 compares /
  // zero-checks don't go through SDAG's slow default expansion.
  auto SplitLoHi = [&](Value *X) -> std::pair<Value *, Value *> {
    Value *Hi = B.CreateTrunc(B.CreateLShr(X, C64(32)), I32);
    Value *Lo = B.CreateTrunc(X, I32);
    return {Lo, Hi};
  };
  auto IsZeroI64 = [&](Value *X) {
    auto [Lo, Hi] = SplitLoHi(X);
    return B.CreateAnd(B.CreateICmpEQ(Lo, C32(0)),
                       B.CreateICmpEQ(Hi, C32(0)));
  };
  auto EqI64Const = [&](Value *X, uint64_t K) {
    auto [Lo, Hi] = SplitLoHi(X);
    return B.CreateAnd(
        B.CreateICmpEQ(Hi, C32(static_cast<uint32_t>(K >> 32))),
        B.CreateICmpEQ(Lo, C32(static_cast<uint32_t>(K))));
  };

  Value *Sign;
  Value *Mag;
  if (IsSigned) {
    // sign = v's high bit
    auto [VLo, VHi] = SplitLoHi(V);
    Value *NegI1 = B.CreateICmpSLT(VHi, C32(0));
    Sign = B.CreateZExt(NegI1, I64);
    Value *VNeg = B.CreateSub(C64(0), V);
    Mag = B.CreateSelect(NegI1, VNeg, V);
  } else {
    Sign = C64(0);
    Mag = V;
  }

  Value *IsZero = IsZeroI64(Mag);

  // ctlz_i64(Mag) → i32 [0, 64].
  Value *LZ32 = emitCtlzI64(B, M, Mag);
  Value *Hi32 = B.CreateSub(C32(63), LZ32);  // 0..63
  Value *ExpBiased32 = B.CreateAdd(Hi32, C32(1023));
  Value *HiGt52 = B.CreateICmpUGT(Hi32, C32(52u));

  // Shift-left arm (hi ≤ 52): no rounding.
  Value *LeftShiftRaw = B.CreateSub(C32(52u), Hi32);
  Value *LeftShift = B.CreateSelect(HiGt52, C32(0u), LeftShiftRaw);
  Value *LeftPath = emitShlI64ByI32(B, Mag, LeftShift);

  // Shift-right arm (hi > 52): RNTE rounding with guard / sticky.
  Value *ShiftRRaw = B.CreateSub(Hi32, C32(52u));      // 1..11
  Value *ShiftR = B.CreateSelect(HiGt52, ShiftRRaw, C32(1u));
  Value *MantTrunc = emitLshrI64ByI32(B, Mag, ShiftR);
  Value *MantTruncBack = emitShlI64ByI32(B, MantTrunc, ShiftR);
  Value *LostBits = B.CreateSub(Mag, MantTruncBack);
  // Guard = bit (ShiftR - 1) of Mag.
  Value *GuardShift = B.CreateSub(ShiftR, C32(1u));
  Value *GuardBitVal = B.CreateLShr(emitLshrI64ByI32(B, Mag, GuardShift), C64(0));
  Value *Guard = B.CreateAnd(GuardBitVal, C64(1));
  // Sticky = (LostBits XOR Guard*(1<<GuardShift)) != 0
  // Simpler: sticky = (LostBits & ((1 << GuardShift) - 1)) != 0
  // i.e. residue below guard.
  Value *GuardOnly = emitShlI64ByI32(B, B.CreateAnd(GuardBitVal, C64(1)),
                                     GuardShift);
  Value *StickyRes = B.CreateSub(LostBits, GuardOnly);
  Value *StickyI1 = IsZeroI64(StickyRes);
  Value *StickyI1NZ = B.CreateNot(StickyI1);
  Value *Sticky = B.CreateZExt(StickyI1NZ, I64);
  // LSB of mantissa (at bit 0 of MantTrunc).
  auto [MtLo, MtHi] = SplitLoHi(MantTrunc);
  Value *Lsb = B.CreateZExt(B.CreateAnd(MtLo, C32(1)), I64);
  Value *RoundUp = B.CreateAnd(Guard, B.CreateOr(Sticky, Lsb));
  Value *MantRounded = B.CreateAdd(MantTrunc, RoundUp);
  // Rounding overflow: mant_rounded == 1 << 53.
  Value *RoundOvf = EqI64Const(MantRounded, 1ULL << 53);
  Value *MantPostRound = B.CreateSelect(RoundOvf,
                                        B.CreateLShr(MantRounded, C64(1)),
                                        MantRounded);
  Value *ExpAfterRound = B.CreateSelect(RoundOvf,
                                        B.CreateAdd(ExpBiased32, C32(1u)),
                                        ExpBiased32);
  // Pick arm.
  Value *MantForPack = B.CreateSelect(HiGt52, MantPostRound, LeftPath);
  Value *ExpForPack = B.CreateSelect(HiGt52, ExpAfterRound, ExpBiased32);

  // Pack.
  Value *MantField = B.CreateAnd(MantForPack, C64(0xFFFFFFFFFFFFFull));
  Value *ExpFor64 = B.CreateZExt(ExpForPack, I64);
  Value *ExpField = B.CreateAnd(B.CreateShl(ExpFor64, C64(52)),
                                C64(0x7FF0000000000000ull));
  Value *SignField = B.CreateShl(Sign, C64(63));
  Value *Packed = B.CreateOr(SignField,
                             B.CreateOr(ExpField, MantField));

  Value *SignedZero = SignField;
  Value *Result = B.CreateSelect(IsZero, SignedZero, Packed);
  B.CreateRet(B.CreateBitCast(Result, F64));
}

static void injectFloatdidfHelpers(Module &M, LLVMContext &Ctx) {
  Type *I64 = Type::getInt64Ty(Ctx);
  Type *F64 = Type::getDoubleTy(Ctx);
  FunctionType *FnTy = FunctionType::get(F64, {I64}, /*isVarArg=*/false);
  if (Function *F = makeOrPromoteHelper(M, "__floatdidf", FnTy))
    emitInt64ToDoubleBody(F, Ctx, M, /*IsSigned=*/true);
  if (Function *F = makeOrPromoteHelper(M, "__floatundidf", FnTy))
    emitInt64ToDoubleBody(F, Ctx, M, /*IsSigned=*/false);
}

// Stage 7h9 — `__fixdfdi (f64) -> i64` / `__fixunsdfdi (f64) -> u64`.
// f64 → i64 truncate-toward-zero with saturation:
//   exp < 1023                ⇒ |d| < 1                    ⇒ 0
//   exp ∈ [1023, 1085]        ⇒ |d| ∈ [1, 2^63)             ⇒ shift
//   exp ≥ 1086 (signed)       ⇒ |d| ≥ 2^63                  ⇒ INT_MIN/MAX
//   exp ≥ 1087 (unsigned)     ⇒ |d| ≥ 2^64                  ⇒ UINT_MAX
//   NaN                                                     ⇒ 0
static void emitDoubleToInt64Body(Function *F, LLVMContext &Ctx,
                                  bool IsSigned) {
  Type *I32 = Type::getInt32Ty(Ctx);
  Type *I64 = Type::getInt64Ty(Ctx);

  Argument *V = F->getArg(0); V->setName("d");
  BasicBlock *BB = BasicBlock::Create(Ctx, "entry", F);
  IRBuilder<> B(BB);
  auto C32 = [&](uint32_t X) { return B.getInt32(X); };
  auto C64 = [&](uint64_t X) { return ConstantInt::get(I64, X); };

  Value *DI64 = B.CreateBitCast(V, I64);
  Value *DHi = B.CreateTrunc(B.CreateLShr(DI64, C64(32)), I32);
  Value *DLo = B.CreateTrunc(DI64, I32);

  Value *Sign = B.CreateLShr(DHi, C32(31));
  Value *Exp = B.CreateAnd(B.CreateLShr(DHi, C32(20)), C32(0x7FFu));
  Value *MantTop = B.CreateAnd(DHi, C32(0xFFFFFu));     // 20 bits
  Value *MantBot = DLo;                                  // 32 bits

  // 53-bit mantissa with implicit 1 packed as i64.
  Value *MantTopHidden = B.CreateOr(MantTop, C32(0x100000u));
  Value *FullMant64 = B.CreateOr(
      B.CreateShl(B.CreateZExt(MantTopHidden, I64), C64(32)),
      B.CreateZExt(MantBot, I64));

  // Underflow gate.
  Value *Underflow = B.CreateICmpULT(Exp, C32(1023u));

  // Shift amount: if exp ≥ 1075, shift left by (exp - 1075); else
  // shift right by (1075 - exp). Both arms clamped to [0, 63] via
  // the existing emitShl/Lshr utilities.
  Value *ExpGe1075 = B.CreateICmpUGE(Exp, C32(1075u));
  Value *ShiftL_raw = B.CreateSub(Exp, C32(1075u));        // wants 0..11
  Value *ShiftL = B.CreateSelect(ExpGe1075, ShiftL_raw, C32(0u));
  Value *ShiftR_raw = B.CreateSub(C32(1075u), Exp);        // wants 0..52
  Value *ShiftR = B.CreateSelect(ExpGe1075, C32(0u), ShiftR_raw);
  Value *LeftPath = emitShlI64ByI32(B, FullMant64, ShiftL);
  Value *RightPath = emitLshrI64ByI32(B, FullMant64, ShiftR);
  Value *MagPath = B.CreateSelect(ExpGe1075, LeftPath, RightPath);

  Value *Result;
  if (IsSigned) {
    // Apply sign.
    Value *NegSignI1 = B.CreateICmpEQ(Sign, C32(1));
    Value *NegMag = B.CreateSub(C64(0), MagPath);
    Result = B.CreateSelect(NegSignI1, NegMag, MagPath);

    // Saturate at |d| ≥ 2^63 (exp ≥ 1086). INT_MIN (= -2^63) is the
    // only exp-1086 value that's representable exactly (sign=1,
    // mant=0); the saturation arm lands on INT_MIN for that case too.
    Value *ExpGe1086 = B.CreateICmpUGE(Exp, C32(1086u));
    Value *PosSat = C64(0x7FFFFFFFFFFFFFFFull);   // INT64_MAX
    Value *NegSat = C64(0x8000000000000000ull);   // INT64_MIN
    Value *Sat = B.CreateSelect(NegSignI1, NegSat, PosSat);
    Result = B.CreateSelect(ExpGe1086, Sat, Result);
  } else {
    Result = MagPath;
    Value *NegSignI1 = B.CreateICmpEQ(Sign, C32(1));
    Value *ExpGe1087 = B.CreateICmpUGE(Exp, C32(1087u));
    Value *PosOverflow = B.CreateAnd(B.CreateNot(NegSignI1), ExpGe1087);
    Result = B.CreateSelect(PosOverflow, C64(0xFFFFFFFFFFFFFFFFull),
                            Result);
    Result = B.CreateSelect(NegSignI1, C64(0), Result);
  }

  // Underflow → 0.
  Result = B.CreateSelect(Underflow, C64(0), Result);

  // NaN → 0 (matches stage-7h8 saturating-intrinsic convention).
  Value *ExpIsMax = B.CreateICmpEQ(Exp, C32(0x7FFu));
  Value *MantNZ = B.CreateOr(B.CreateICmpNE(MantTop, C32(0u)),
                             B.CreateICmpNE(MantBot, C32(0u)));
  Value *IsNaN = B.CreateAnd(ExpIsMax, MantNZ);
  Result = B.CreateSelect(IsNaN, C64(0), Result);

  B.CreateRet(Result);
}

static void injectFixdfdiHelpers(Module &M, LLVMContext &Ctx) {
  Type *I64 = Type::getInt64Ty(Ctx);
  Type *F64 = Type::getDoubleTy(Ctx);
  FunctionType *FnTy = FunctionType::get(I64, {F64}, /*isVarArg=*/false);
  if (Function *F = makeOrPromoteHelper(M, "__fixdfdi", FnTy))
    emitDoubleToInt64Body(F, Ctx, /*IsSigned=*/true);
  if (Function *F = makeOrPromoteHelper(M, "__fixunsdfdi", FnTy))
    emitDoubleToInt64Body(F, Ctx, /*IsSigned=*/false);
}

// Stage 7h4 — variable-amount i64 shift utilities. The backend can't
// select `shl_parts` directly, so we emulate variable-amount i64
// shifts via clamped i32-pair operations (same technique as stage
// 7h3's i32 ↔ f64 conversions). The shift amount must be ≤ 63;
// arms are clamped so each individual i32 shift stays in [0, 31].
//
// These helpers emit IR that:
//   1. splits X into (hi, lo) via `lshr X, 32` + trunc
//   2. computes the result hi/lo on each arm (amt < 32 and amt ≥ 32)
//      with shift counts clamped to a defined range
//   3. selects between the arms with i32 selects (bit-blended)
//   4. recombines into i64 via constant-amount shl + or
static Value *emitLshrI64ByI32(IRBuilder<> &B, Value *X, Value *Amt) {
  LLVMContext &Ctx = B.getContext();
  Type *I32 = Type::getInt32Ty(Ctx);
  Type *I64 = Type::getInt64Ty(Ctx);
  Value *C32_32 = ConstantInt::get(I32, 32);
  Value *C32_31 = ConstantInt::get(I32, 31);
  Value *C32_1 = ConstantInt::get(I32, 1);
  Value *C32_0 = ConstantInt::get(I32, 0);

  Value *Hi = B.CreateTrunc(B.CreateLShr(X, ConstantInt::get(I64, 32)), I32);
  Value *Lo = B.CreateTrunc(X, I32);

  auto Clamp31 = [&](Value *V) {
    return B.CreateSelect(B.CreateICmpUGT(V, C32_31), C32_31, V);
  };
  Value *Big = B.CreateICmpUGE(Amt, C32_32);
  // Codex-review P1: when Amt == 0 the small-arm cross-half shift
  // amount is (32 - 0) = 32, which the i32 clamp folds to 31, so
  // the bit-blended `lshr X, 0` would OR `Hi << 31` into the
  // result low half. Force the cross-half contribution to zero
  // when Amt is zero.
  Value *AmtIsZero = B.CreateICmpEQ(Amt, C32_0);

  Value *SmallShiftR = Clamp31(B.CreateSelect(Big, C32_1, Amt));
  Value *SmallShiftL = Clamp31(B.CreateSelect(
      Big, C32_0, B.CreateSub(C32_32, Amt)));
  Value *SmallCross = B.CreateSelect(AmtIsZero, C32_0,
                                     B.CreateShl(Hi, SmallShiftL));
  Value *SmallLo = B.CreateOr(B.CreateLShr(Lo, SmallShiftR), SmallCross);
  Value *SmallHi = B.CreateLShr(Hi, SmallShiftR);

  Value *BigShift = Clamp31(B.CreateSelect(
      Big, B.CreateSub(Amt, C32_32), C32_0));
  Value *BigLo = B.CreateLShr(Hi, BigShift);
  Value *BigHi = C32_0;

  Value *ResLo = B.CreateSelect(Big, BigLo, SmallLo);
  Value *ResHi = B.CreateSelect(Big, BigHi, SmallHi);

  return B.CreateOr(
      B.CreateShl(B.CreateZExt(ResHi, I64), ConstantInt::get(I64, 32)),
      B.CreateZExt(ResLo, I64));
}

static Value *emitShlI64ByI32(IRBuilder<> &B, Value *X, Value *Amt) {
  LLVMContext &Ctx = B.getContext();
  Type *I32 = Type::getInt32Ty(Ctx);
  Type *I64 = Type::getInt64Ty(Ctx);
  Value *C32_32 = ConstantInt::get(I32, 32);
  Value *C32_31 = ConstantInt::get(I32, 31);
  Value *C32_1 = ConstantInt::get(I32, 1);
  Value *C32_0 = ConstantInt::get(I32, 0);

  Value *Hi = B.CreateTrunc(B.CreateLShr(X, ConstantInt::get(I64, 32)), I32);
  Value *Lo = B.CreateTrunc(X, I32);

  auto Clamp31 = [&](Value *V) {
    return B.CreateSelect(B.CreateICmpUGT(V, C32_31), C32_31, V);
  };
  Value *Big = B.CreateICmpUGE(Amt, C32_32);
  // Same Amt == 0 cross-half gate as `emitLshrI64ByI32` above.
  Value *AmtIsZero = B.CreateICmpEQ(Amt, C32_0);

  Value *SmallShiftL = Clamp31(B.CreateSelect(Big, C32_1, Amt));
  Value *SmallShiftR = Clamp31(B.CreateSelect(
      Big, C32_0, B.CreateSub(C32_32, Amt)));
  Value *SmallCross = B.CreateSelect(AmtIsZero, C32_0,
                                     B.CreateLShr(Lo, SmallShiftR));
  Value *SmallHi = B.CreateOr(B.CreateShl(Hi, SmallShiftL), SmallCross);
  Value *SmallLo = B.CreateShl(Lo, SmallShiftL);

  Value *BigShift = Clamp31(B.CreateSelect(
      Big, B.CreateSub(Amt, C32_32), C32_0));
  Value *BigHi = B.CreateShl(Lo, BigShift);
  Value *BigLo = C32_0;

  Value *ResHi = B.CreateSelect(Big, BigHi, SmallHi);
  Value *ResLo = B.CreateSelect(Big, BigLo, SmallLo);

  return B.CreateOr(
      B.CreateShl(B.CreateZExt(ResHi, I64), ConstantInt::get(I64, 32)),
      B.CreateZExt(ResLo, I64));
}

// ctlz of an i64 value, computed via two i32 ctlz calls. Returns an
// i32 in [0, 64].
static Value *emitCtlzI64(IRBuilder<> &B, Module &M, Value *X) {
  LLVMContext &Ctx = B.getContext();
  Type *I32 = Type::getInt32Ty(Ctx);
  Type *I64 = Type::getInt64Ty(Ctx);

  Function *Ctlz =
      Intrinsic::getOrInsertDeclaration(&M, Intrinsic::ctlz, {I32});

  Value *Hi = B.CreateTrunc(B.CreateLShr(X, ConstantInt::get(I64, 32)), I32);
  Value *Lo = B.CreateTrunc(X, I32);

  Value *HiNonZero = B.CreateICmpNE(Hi, ConstantInt::get(I32, 0));
  Value *LzHi = B.CreateCall(Ctlz, {Hi, ConstantInt::getFalse(Ctx)});
  Value *LzLo = B.CreateCall(Ctlz, {Lo, ConstantInt::getFalse(Ctx)});
  Value *LzLoPlus32 = B.CreateAdd(LzLo, ConstantInt::get(I32, 32));
  return B.CreateSelect(HiNonZero, LzHi, LzLoPlus32);
}

// Stage 7h4 — `__adddf3 (a, b) -> double`. IEEE-754 double-precision
// addition. Mirrors `__addsf3` in structure but operates on the
// 53-bit mantissa (plus 3-bit guard region for rounding) packed into
// i64 values. Variable-amount i64 shifts use the
// `emitLshrI64ByI32` / `emitShlI64ByI32` clamped-arm split helpers.
//
// Limitations (carried over from `__addsf3`):
//   - Inf / NaN handling: 7g4-style override at the tail
//   - Denormal inputs flush to zero, denormal results flush to zero
//   - Rounding: round-to-nearest, ties-to-even with guard / round /
//     sticky bits
//
// Bit positions in MSum (the post-add mantissa, in i64):
//   bit 56 = post-add carry-out      (ctlz == 7)
//   bit 55 = normal-form MSB          (ctlz == 8)
//   bit < 55 = subtraction left-normalises by (8 - ctlz)
static void injectAddDf3Helper(Module &M, LLVMContext &Ctx) {
  Type *F64 = Type::getDoubleTy(Ctx);
  Type *I32 = Type::getInt32Ty(Ctx);
  Type *I64 = Type::getInt64Ty(Ctx);
  FunctionType *FnTy = FunctionType::get(F64, {F64, F64}, /*isVarArg=*/false);

  Function *F = makeOrPromoteHelper(M, "__adddf3", FnTy);
  if (!F)
    return;

  F->getArg(0)->setName("a");
  F->getArg(1)->setName("b");

  BasicBlock *Entry = BasicBlock::Create(Ctx, "entry", F);
  IRBuilder<> B(Entry);
  auto C64 = [&](uint64_t V) { return ConstantInt::get(I64, V); };
  auto C32 = [&](uint32_t V) { return ConstantInt::get(I32, V); };

  Value *AI = B.CreateBitCast(F->getArg(0), I64, "ai");
  Value *BI = B.CreateBitCast(F->getArg(1), I64, "bi");

  // i64 compare lowering on this backend is slow (default SDAG
  // expansion creates many branchy SETCC nodes whose interaction
  // with the bit-blended selects pushes DAG-ISel into multi-minute
  // compile times; observed on stage-7h4 bring-up). Express each
  // i64 compare as a manual {hi, lo} i32 pair compare, mirroring
  // the 7h2 f64 fcmp pattern.
  auto SplitLoHi = [&](Value *X) -> std::pair<Value *, Value *> {
    Value *Hi = B.CreateTrunc(B.CreateLShr(X, C64(32)), I32);
    Value *Lo = B.CreateTrunc(X, I32);
    return {Lo, Hi};
  };
  auto IsNonZeroI64 = [&](Value *X) {
    auto [Lo, Hi] = SplitLoHi(X);
    return B.CreateOr(B.CreateICmpNE(Lo, C32(0)),
                      B.CreateICmpNE(Hi, C32(0)));
  };
  auto IsZeroI64 = [&](Value *X) {
    auto [Lo, Hi] = SplitLoHi(X);
    return B.CreateAnd(B.CreateICmpEQ(Lo, C32(0)),
                       B.CreateICmpEQ(Hi, C32(0)));
  };
  auto EqI64Const = [&](Value *X, uint64_t K) {
    auto [Lo, Hi] = SplitLoHi(X);
    return B.CreateAnd(
        B.CreateICmpEQ(Hi, C32(static_cast<uint32_t>(K >> 32))),
        B.CreateICmpEQ(Lo, C32(static_cast<uint32_t>(K))));
  };
  auto UgeI64 = [&](Value *A, Value *Bv) {
    auto [aLo, aHi] = SplitLoHi(A);
    auto [bLo, bHi] = SplitLoHi(Bv);
    Value *HiGt = B.CreateICmpUGT(aHi, bHi);
    Value *HiEq = B.CreateICmpEQ(aHi, bHi);
    Value *LoUge = B.CreateICmpUGE(aLo, bLo);
    return B.CreateOr(HiGt, B.CreateAnd(HiEq, LoUge));
  };

  // Field extraction.
  Value *SA = B.CreateLShr(AI, C64(63));
  Value *SB = B.CreateLShr(BI, C64(63));
  Value *EA64 = B.CreateAnd(B.CreateLShr(AI, C64(52)), C64(0x7FFull));
  Value *EB64 = B.CreateAnd(B.CreateLShr(BI, C64(52)), C64(0x7FFull));
  Value *EA = B.CreateTrunc(EA64, I32, "ea");
  Value *EB = B.CreateTrunc(EB64, I32, "eb");
  Value *MARaw = B.CreateAnd(AI, C64(0xFFFFFFFFFFFFFull));
  Value *MBRaw = B.CreateAnd(BI, C64(0xFFFFFFFFFFFFFull));

  // Implicit-1 + 3-bit guard region. MSB now at bit 55.
  Value *MAN = B.CreateOr(MARaw, C64(0x10000000000000ull));   // 1 << 52
  Value *MBN = B.CreateOr(MBRaw, C64(0x10000000000000ull));
  Value *MAG = B.CreateShl(MAN, C64(3), "ma_g");
  Value *MBG = B.CreateShl(MBN, C64(3), "mb_g");

  // Order by magnitude via i32-pair compare (see SplitLoHi rationale
  // above). Sign-stripped i64 compare would otherwise route through
  // the slow SDAG default.
  Value *AMag = B.CreateAnd(AI, C64(0x7FFFFFFFFFFFFFFFull));
  Value *BMag = B.CreateAnd(BI, C64(0x7FFFFFFFFFFFFFFFull));
  Value *AGeB = UgeI64(AMag, BMag);

  Value *ReInit = B.CreateSelect(AGeB, EA, EB, "re_init");
  Value *EDab = B.CreateSub(EA, EB);
  Value *EDba = B.CreateSub(EB, EA);
  Value *EDraw = B.CreateSelect(AGeB, EDab, EDba, "ed_raw");
  Value *EDtooBig = B.CreateICmpUGT(EDraw, C32(63u));
  Value *ED = B.CreateSelect(EDtooBig, C32(63u), EDraw, "ed");

  Value *MLarge = B.CreateSelect(AGeB, MAG, MBG, "m_large");
  Value *MSmall = B.CreateSelect(AGeB, MBG, MAG, "m_small");
  Value *SLarge = B.CreateSelect(AGeB, SA, SB);
  Value *SSmall = B.CreateSelect(AGeB, SB, SA);

  // Right-shift smaller mantissa by ED, with sticky.
  Value *MSmallShifted = emitLshrI64ByI32(B, MSmall, ED);
  Value *MSmallShiftedBack = emitShlI64ByI32(B, MSmallShifted, ED);
  Value *Discarded = B.CreateSub(MSmall, MSmallShiftedBack);
  Value *StickyI1 = IsNonZeroI64(Discarded);
  Value *MSmallNonZero = IsNonZeroI64(MSmall);
  Value *ExtraSticky = B.CreateAnd(EDtooBig, MSmallNonZero);
  Value *StickyAll = B.CreateOr(StickyI1, ExtraSticky);
  Value *StickyBit64 = B.CreateZExt(StickyAll, I64);
  Value *MSmallWithSticky = B.CreateOr(MSmallShifted, StickyBit64);

  // Same-sign add, different-sign subtract.
  Value *SignsEqual = B.CreateICmpEQ(SLarge, SSmall);
  Value *SumAdd = B.CreateAdd(MLarge, MSmallWithSticky);
  Value *SumSub = B.CreateSub(MLarge, MSmallWithSticky);
  Value *MSum = B.CreateSelect(SignsEqual, SumAdd, SumSub, "m_sum");

  // Cancel-to-zero.
  Value *CancelZero = B.CreateAnd(B.CreateNot(SignsEqual),
                                  IsZeroI64(MSum));

  // Normalize via ctlz. MSum has MSB:
  //   bit 56 = post-add carry-out (lz == 7)
  //   bit 55 = normal             (lz == 8)
  //   bit < 55 = subtraction left-normalises by (8 - lz)
  Value *LZ = emitCtlzI64(B, M, MSum);

  // Overflow path (lz == 7).
  Value *LzEq7 = B.CreateICmpEQ(LZ, C32(7u));
  Value *StickyOvf = B.CreateAnd(MSum, C64(1));
  Value *MSumOvf = B.CreateOr(B.CreateLShr(MSum, C64(1)), StickyOvf);
  Value *ReOvf = B.CreateAdd(ReInit, C32(1u));

  // Underflow path (lz > 8).
  Value *LzGt8 = B.CreateICmpUGT(LZ, C32(8u));
  Value *LzMinus8Safe = B.CreateSelect(LzGt8,
                                       B.CreateSub(LZ, C32(8u)), C32(0u));
  Value *MaxShift = B.CreateSub(ReInit, C32(1u));
  Value *ShiftA = B.CreateSelect(
      B.CreateICmpULT(LzMinus8Safe, MaxShift), LzMinus8Safe, MaxShift);
  // Final shift-width clamp: 55 fully normalises any 56-bit mantissa.
  Value *ShiftCap = B.CreateSelect(
      B.CreateICmpULT(ShiftA, C32(55u)), ShiftA, C32(55u));
  Value *MSumUnf = emitShlI64ByI32(B, MSum, ShiftCap);
  Value *ReUnf = B.CreateSub(ReInit, ShiftCap);

  // Combine normalize paths.
  Value *MSumPost = B.CreateSelect(LzEq7, MSumOvf,
                       B.CreateSelect(LzGt8, MSumUnf, MSum));
  Value *RePost = B.CreateSelect(LzEq7, ReOvf,
                       B.CreateSelect(LzGt8, ReUnf, ReInit));

  // Round to nearest, ties to even.
  Value *GuardBit = B.CreateAnd(B.CreateLShr(MSumPost, C64(2)), C64(1));
  Value *RoundBit = B.CreateAnd(B.CreateLShr(MSumPost, C64(1)), C64(1));
  Value *StickyBit2 = B.CreateAnd(MSumPost, C64(1));
  Value *MSumTrunc = B.CreateLShr(MSumPost, C64(3));
  Value *Lsb = B.CreateAnd(MSumTrunc, C64(1));
  Value *RoundOrSticky = B.CreateOr(RoundBit, StickyBit2);
  Value *RoundOrLsb = B.CreateOr(RoundOrSticky, Lsb);
  Value *NeedRoundUp = B.CreateAnd(GuardBit, RoundOrLsb);
  Value *MSumRounded = B.CreateAdd(MSumTrunc, NeedRoundUp);

  // Round may bump mantissa to 1 << 53 → shift right and exp + 1.
  Value *RoundedOvf = EqI64Const(MSumRounded, 0x20000000000000ull);
  Value *MSumFinal = B.CreateSelect(RoundedOvf,
                                    B.CreateLShr(MSumRounded, C64(1)),
                                    MSumRounded);
  Value *ReFinalRaw = B.CreateSelect(RoundedOvf, B.CreateAdd(RePost, C32(1u)),
                                     RePost);

  // Pack the IEEE-754 fields back into i64.
  Value *MantField = B.CreateAnd(MSumFinal, C64(0xFFFFFFFFFFFFFull));
  Value *ReFinal64 = B.CreateZExt(ReFinalRaw, I64);
  Value *ExpField = B.CreateAnd(B.CreateShl(ReFinal64, C64(52)),
                                C64(0x7FF0000000000000ull));
  Value *SignField = B.CreateShl(SLarge, C64(63));
  Value *Packed = B.CreateOr(SignField, B.CreateOr(ExpField, MantField));

  // Exponent overflow → signed Inf.
  Value *ExpOvf = B.CreateICmpUGE(ReFinalRaw, C32(2047u));
  Value *InfBits = B.CreateOr(B.CreateShl(SLarge, C64(63)),
                              C64(0x7FF0000000000000ull));
  Value *PostOvf = B.CreateSelect(ExpOvf, InfBits, Packed);

  // Zero / denormal pass-through, then cancel-to-zero.
  Value *AIsZero = B.CreateICmpEQ(EA, C32(0u));
  Value *BIsZero = B.CreateICmpEQ(EB, C32(0u));
  Value *Step1 = B.CreateSelect(AIsZero, BI, PostOvf);
  Value *Step2 = B.CreateSelect(BIsZero, AI, Step1);
  Value *Step3 = B.CreateSelect(CancelZero, C64(0), Step2);

  // Stage 7g4-style Inf / NaN propagation.
  Value *EAMax = B.CreateICmpEQ(EA, C32(0x7FFu));
  Value *EBMax = B.CreateICmpEQ(EB, C32(0x7FFu));
  Value *MANonZero = IsNonZeroI64(MARaw);
  Value *MBNonZero = IsNonZeroI64(MBRaw);
  Value *AIsNaN = B.CreateAnd(EAMax, MANonZero);
  Value *BIsNaN = B.CreateAnd(EBMax, MBNonZero);
  Value *AIsInf = B.CreateAnd(EAMax, B.CreateNot(MANonZero));
  Value *BIsInf = B.CreateAnd(EBMax, B.CreateNot(MBNonZero));
  Value *BothInf = B.CreateAnd(AIsInf, BIsInf);
  Value *SignSame = B.CreateICmpEQ(SA, SB);
  Value *InfMinusInf = B.CreateAnd(BothInf, B.CreateNot(SignSame));
  Value *EitherNaN = B.CreateOr(AIsNaN, BIsNaN);
  Value *NaNCase = B.CreateOr(EitherNaN, InfMinusInf);
  Value *AnyInf = B.CreateOr(AIsInf, BIsInf);
  Value *InfBitsPick = B.CreateSelect(AIsInf, AI, BI);

  Value *WithInf = B.CreateSelect(AnyInf, InfBitsPick, Step3);
  Value *WithNaN = B.CreateSelect(NaNCase, C64(0x7FF8000000000000ull),
                                  WithInf);

  B.CreateRet(B.CreateBitCast(WithNaN, F64));
}

// Stage 7h4 — `__subdf3 (a, b)` = `__adddf3 (a, -b)`. Flip the sign
// bit (bit 63) of `b` and delegate. Same shape as `__subsf3`.
static void injectSubDf3Helper(Module &M, LLVMContext &Ctx) {
  Type *F64 = Type::getDoubleTy(Ctx);
  Type *I64 = Type::getInt64Ty(Ctx);
  FunctionType *FnTy = FunctionType::get(F64, {F64, F64}, /*isVarArg=*/false);
  Function *F = makeOrPromoteHelper(M, "__subdf3", FnTy);
  if (!F)
    return;
  F->getArg(0)->setName("a");
  F->getArg(1)->setName("b");

  FunctionCallee AddDf3 = M.getOrInsertFunction("__adddf3", FnTy);

  BasicBlock *BB = BasicBlock::Create(Ctx, "entry", F);
  IRBuilder<> B(BB);
  Value *BI = B.CreateBitCast(F->getArg(1), I64);
  Value *NegBI = B.CreateXor(BI, ConstantInt::get(I64, 0x8000000000000000ull));
  Value *NegB = B.CreateBitCast(NegBI, F64);
  Value *R = B.CreateCall(AddDf3, {F->getArg(0), NegB});
  B.CreateRet(R);
}

// Stage 7h5 — full 32×32 → 64-bit unsigned multiply, computed via
// four 16×16 → 32-bit `mul i32` sub-multiplies (which the stage-7f1
// byte-table lowering handles). Returns an i64. The naive `zext +
// mul i64` approach would push SDAG into wide-mul lowerings we
// don't support directly.
static Value *emitMulU32U32ToI64(IRBuilder<> &B, Value *A, Value *Bv) {
  LLVMContext &Ctx = B.getContext();
  Type *I32 = Type::getInt32Ty(Ctx);
  Type *I64 = Type::getInt64Ty(Ctx);
  Value *MaskLo16 = ConstantInt::get(I32, 0xFFFFu);
  Value *Sixteen = ConstantInt::get(I32, 16);

  // 16-bit decomposition.
  Value *ALo = B.CreateAnd(A, MaskLo16);
  Value *AHi = B.CreateLShr(A, Sixteen);
  Value *BLo = B.CreateAnd(Bv, MaskLo16);
  Value *BHi = B.CreateLShr(Bv, Sixteen);

  // Four partial 16×16 products, each fits in i32.
  Value *Pll = B.CreateMul(ALo, BLo);   // bits 31..0
  Value *Plh = B.CreateMul(ALo, BHi);   // bits 47..16
  Value *Phl = B.CreateMul(AHi, BLo);   // bits 47..16
  Value *Phh = B.CreateMul(AHi, BHi);   // bits 63..32

  // Sum p_lh + p_hl. Up to 33 bits; capture the carry-out (bit 32).
  Value *Mid = B.CreateAdd(Plh, Phl);
  Value *MidCarry = B.CreateZExt(B.CreateICmpULT(Mid, Plh), I32);
  Value *MidLoShifted = B.CreateShl(B.CreateAnd(Mid, MaskLo16), Sixteen);
  Value *MidHi = B.CreateLShr(Mid, Sixteen);

  // Low 32 bits of the 64-bit product.
  Value *Low32 = B.CreateAdd(Pll, MidLoShifted);
  Value *CarryLo = B.CreateZExt(B.CreateICmpULT(Low32, Pll), I32);

  // High 32 bits: p_hh + mid_hi17 + carry_lo. mid_hi17 = MidHi |
  // (MidCarry << 16).
  Value *MidHi17 = B.CreateOr(MidHi, B.CreateShl(MidCarry, Sixteen));
  Value *High32 = B.CreateAdd(B.CreateAdd(Phh, MidHi17), CarryLo);

  // Combine into i64 via constant-amount shl.
  Value *Low64 = B.CreateZExt(Low32, I64);
  Value *High64 = B.CreateZExt(High32, I64);
  return B.CreateOr(B.CreateShl(High64, ConstantInt::get(I64, 32)), Low64);
}

// Stage 7h5 — `__muldf3 (a, b) -> double`. IEEE-754 double-precision
// multiply. Same structure as `__mulsf3` but scaled to f64's 53-bit
// mantissa with a 106-bit intermediate product.
//
// The mantissa multiply is a 53×53 → 106-bit product computed via
// four 32×32 → 64-bit sub-multiplies on the (lo32, hi21) split of
// each mantissa. The 106-bit product is held as two i64 halves
// `{high64, low64}` (= bits 127..64, bits 63..0 of the conceptual
// 128-bit value with the upper 22 bits guaranteed zero).
//
// Bit positions of the 106-bit product:
//   bit 105 = top of product when "case A" (post-mul carry-out)
//   bit 104 = top of product when "case B" (the more common case)
// (Compared to f32: 47 / 46. Same shape, +58 bits.)
//
// In `high64` (which holds bits 127..64 of the product):
//   bit 41 = bit 105 of product
//   bit 40 = bit 104 of product
//
// Normalisation extracts the top 54 bits as the mantissa (with
// implicit-1); guard / sticky come from the bits just below that
// window. Round-to-nearest-ties-to-even, mantissa-overflow bump,
// pack {sign, exp, mant}. Same flush-to-zero envelope as the f64
// add helper: either-input-zero ⇒ signed zero; overflow ⇒ signed
// Inf; underflow ⇒ signed zero; stage-7g4 Inf / NaN propagation.
static void injectMulDf3Helper(Module &M, LLVMContext &Ctx) {
  Type *F64 = Type::getDoubleTy(Ctx);
  Type *I32 = Type::getInt32Ty(Ctx);
  Type *I64 = Type::getInt64Ty(Ctx);
  FunctionType *FnTy = FunctionType::get(F64, {F64, F64}, /*isVarArg=*/false);

  Function *F = makeOrPromoteHelper(M, "__muldf3", FnTy);
  if (!F)
    return;

  F->getArg(0)->setName("a");
  F->getArg(1)->setName("b");

  BasicBlock *Entry = BasicBlock::Create(Ctx, "entry", F);
  IRBuilder<> B(Entry);
  auto C64 = [&](uint64_t V) { return ConstantInt::get(I64, V); };
  auto C32 = [&](uint32_t V) { return ConstantInt::get(I32, V); };

  Value *AI = B.CreateBitCast(F->getArg(0), I64, "ai");
  Value *BI = B.CreateBitCast(F->getArg(1), I64, "bi");

  // i32-pair compare helpers (same shape as 7h4).
  auto SplitLoHi = [&](Value *X) -> std::pair<Value *, Value *> {
    Value *Hi = B.CreateTrunc(B.CreateLShr(X, C64(32)), I32);
    Value *Lo = B.CreateTrunc(X, I32);
    return {Lo, Hi};
  };
  auto IsNonZeroI64 = [&](Value *X) {
    auto [Lo, Hi] = SplitLoHi(X);
    return B.CreateOr(B.CreateICmpNE(Lo, C32(0)),
                      B.CreateICmpNE(Hi, C32(0)));
  };
  auto EqI64Const = [&](Value *X, uint64_t K) {
    auto [Lo, Hi] = SplitLoHi(X);
    return B.CreateAnd(
        B.CreateICmpEQ(Hi, C32(static_cast<uint32_t>(K >> 32))),
        B.CreateICmpEQ(Lo, C32(static_cast<uint32_t>(K))));
  };
  auto UltI64 = [&](Value *A, Value *Bv) {
    auto [aLo, aHi] = SplitLoHi(A);
    auto [bLo, bHi] = SplitLoHi(Bv);
    Value *HiLt = B.CreateICmpULT(aHi, bHi);
    Value *HiEq = B.CreateICmpEQ(aHi, bHi);
    Value *LoLt = B.CreateICmpULT(aLo, bLo);
    return B.CreateOr(HiLt, B.CreateAnd(HiEq, LoLt));
  };

  // Field extraction.
  Value *SA = B.CreateLShr(AI, C64(63));
  Value *SB = B.CreateLShr(BI, C64(63));
  Value *EA64 = B.CreateAnd(B.CreateLShr(AI, C64(52)), C64(0x7FFull));
  Value *EB64 = B.CreateAnd(B.CreateLShr(BI, C64(52)), C64(0x7FFull));
  Value *EA = B.CreateTrunc(EA64, I32, "ea");
  Value *EB = B.CreateTrunc(EB64, I32, "eb");
  Value *MARaw = B.CreateAnd(AI, C64(0xFFFFFFFFFFFFFull));
  Value *MBRaw = B.CreateAnd(BI, C64(0xFFFFFFFFFFFFFull));

  // Result sign.
  Value *SR = B.CreateXor(SA, SB);

  // Either-zero / NaN-input detection.
  Value *AIsZero = B.CreateICmpEQ(EA, C32(0));
  Value *BIsZero = B.CreateICmpEQ(EB, C32(0));
  Value *EitherZero = B.CreateOr(AIsZero, BIsZero);

  // Add implicit-1.
  Value *MA = B.CreateOr(MARaw, C64(0x10000000000000ull));
  Value *MB = B.CreateOr(MBRaw, C64(0x10000000000000ull));

  // 53×53 → 106-bit mantissa multiply.
  Value *MaLo32 = B.CreateTrunc(MA, I32);
  Value *MaHi32 = B.CreateTrunc(B.CreateLShr(MA, C64(32)), I32);
  Value *MbLo32 = B.CreateTrunc(MB, I32);
  Value *MbHi32 = B.CreateTrunc(B.CreateLShr(MB, C64(32)), I32);

  Value *Pll = emitMulU32U32ToI64(B, MaLo32, MbLo32);
  Value *Plh = emitMulU32U32ToI64(B, MaLo32, MbHi32);
  Value *Phl = emitMulU32U32ToI64(B, MaHi32, MbLo32);
  Value *Phh = emitMulU32U32ToI64(B, MaHi32, MbHi32);

  // Combine partial products into {High64, Low64} = full 128-bit
  // (effectively 106-bit) product.
  Value *Mid = B.CreateAdd(Plh, Phl);
  Value *MidCarryI1 = UltI64(Mid, Plh);
  Value *MidCarry64 = B.CreateZExt(MidCarryI1, I64);
  Value *MidLo32 = B.CreateAnd(Mid, C64(0xFFFFFFFFull));
  Value *MidHi32_64 = B.CreateLShr(Mid, C64(32));
  Value *MidLoShifted = B.CreateShl(MidLo32, C64(32));

  Value *Low64 = B.CreateAdd(Pll, MidLoShifted);
  Value *LowCarryI1 = UltI64(Low64, Pll);
  Value *LowCarry64 = B.CreateZExt(LowCarryI1, I64);

  Value *MidHiFull = B.CreateOr(MidHi32_64,
                                B.CreateShl(MidCarry64, C64(32)));
  Value *High64 = B.CreateAdd(B.CreateAdd(Phh, MidHiFull), LowCarry64);

  // Normalise: bit 105 of product = bit 41 of High64. If set, "case A".
  Value *TopBit41 = B.CreateAnd(B.CreateLShr(High64, C64(41)), C64(1));
  Value *TopBit41I1 = EqI64Const(TopBit41, 1);

  // Case A (bit 105 set): keep bits [105:53] as a 53-bit mantissa
  // (bit 52 = implicit-1 of result, bits 51..0 = fractional bits).
  //   bits 105..64 = High64[41:0]  → mant_pre_A bits 52..11 (shl 11)
  //   bits 63..53  = Low64[63:53]  → mant_pre_A bits 10..0 (lshr 53)
  //   guard_A      = (Low64 >> 52) & 1
  //   sticky_A     = (Low64 & ((1ULL<<52) - 1)) != 0
  Value *MantPreA = B.CreateOr(
      B.CreateShl(B.CreateAnd(High64, C64(0x3FFFFFFFFFFull)), C64(11)),
      B.CreateLShr(Low64, C64(53)));
  Value *GuardA = B.CreateAnd(B.CreateLShr(Low64, C64(52)), C64(1));
  Value *StickyAI1 = IsNonZeroI64(
      B.CreateAnd(Low64, C64((1ULL << 52) - 1)));
  Value *StickyA = B.CreateZExt(StickyAI1, I64);

  // Case B (bit 104 set): keep bits [104:52] as a 53-bit mantissa.
  //   bits 104..64 = High64[40:0]  → mant_pre_B bits 52..12 (shl 12)
  //   bits 63..52  = Low64[63:52]  → mant_pre_B bits 11..0 (lshr 52)
  //   guard_B      = (Low64 >> 51) & 1
  //   sticky_B     = (Low64 & ((1ULL<<51) - 1)) != 0
  Value *MantPreB = B.CreateOr(
      B.CreateShl(B.CreateAnd(High64, C64(0x1FFFFFFFFFFull)), C64(12)),
      B.CreateLShr(Low64, C64(52)));
  Value *GuardB = B.CreateAnd(B.CreateLShr(Low64, C64(51)), C64(1));
  Value *StickyBI1 = IsNonZeroI64(
      B.CreateAnd(Low64, C64((1ULL << 51) - 1)));
  Value *StickyB = B.CreateZExt(StickyBI1, I64);

  // Rounding (RNTE), case A.
  Value *LsbA = B.CreateAnd(MantPreA, C64(1));
  Value *RoundUpA = B.CreateAnd(GuardA, B.CreateOr(StickyA, LsbA));
  Value *MantRoundedA = B.CreateAdd(MantPreA, RoundUpA);
  Value *MantOvfA = EqI64Const(MantRoundedA, 1ULL << 53);
  Value *MantPostA = B.CreateSelect(MantOvfA,
                                    B.CreateLShr(MantRoundedA, C64(1)),
                                    MantRoundedA);

  // Rounding (RNTE), case B.
  Value *LsbB = B.CreateAnd(MantPreB, C64(1));
  Value *RoundUpB = B.CreateAnd(GuardB, B.CreateOr(StickyB, LsbB));
  Value *MantRoundedB = B.CreateAdd(MantPreB, RoundUpB);
  Value *MantOvfB = EqI64Const(MantRoundedB, 1ULL << 53);
  Value *MantPostB = B.CreateSelect(MantOvfB,
                                    B.CreateLShr(MantRoundedB, C64(1)),
                                    MantRoundedB);

  // Result exponent. ExpSum fits in i32 (each ≤ 0x7FF).
  Value *ExpSum = B.CreateAdd(EA, EB, "exp_sum");
  Value *ErA = B.CreateSub(ExpSum, C32(1022u));  // = expSum - 1023 + 1
  Value *ErAFinal = B.CreateSelect(MantOvfA,
                                   B.CreateAdd(ErA, C32(1u)), ErA);
  Value *ErB = B.CreateSub(ExpSum, C32(1023u));
  Value *ErBFinal = B.CreateSelect(MantOvfB,
                                   B.CreateAdd(ErB, C32(1u)), ErB);

  // Pick case A or B.
  Value *MantPost = B.CreateSelect(TopBit41I1, MantPostA, MantPostB);
  Value *ErFinal = B.CreateSelect(TopBit41I1, ErAFinal, ErBFinal);

  // Pack.
  Value *MantField = B.CreateAnd(MantPost, C64(0xFFFFFFFFFFFFFull));
  Value *ErFinal64 = B.CreateZExt(ErFinal, I64);
  Value *ExpField = B.CreateAnd(B.CreateShl(ErFinal64, C64(52)),
                                C64(0x7FF0000000000000ull));
  Value *SignField = B.CreateShl(SR, C64(63));
  Value *Packed = B.CreateOr(SignField, B.CreateOr(ExpField, MantField));

  // Underflow / overflow on signed exponent. ErFinal is i32 signed.
  Value *Underflow = B.CreateICmpSLE(ErFinal, C32(0), "underflow");
  Value *Overflow = B.CreateICmpSGE(ErFinal, C32(2047), "overflow");
  Value *SignedZero = SignField;
  Value *SignedInf = B.CreateOr(SignField, C64(0x7FF0000000000000ull));

  Value *Result = B.CreateSelect(Overflow, SignedInf, Packed);
  Result = B.CreateSelect(Underflow, SignedZero, Result);
  Result = B.CreateSelect(EitherZero, SignedZero, Result);

  // Stage 7g4-style Inf / NaN propagation.
  Value *EAMax = B.CreateICmpEQ(EA, C32(0x7FFu));
  Value *EBMax = B.CreateICmpEQ(EB, C32(0x7FFu));
  Value *MANonZero = IsNonZeroI64(MARaw);
  Value *MBNonZero = IsNonZeroI64(MBRaw);
  Value *AIsNaN = B.CreateAnd(EAMax, MANonZero);
  Value *BIsNaN = B.CreateAnd(EBMax, MBNonZero);
  Value *AIsInf = B.CreateAnd(EAMax, B.CreateNot(MANonZero));
  Value *BIsInf = B.CreateAnd(EBMax, B.CreateNot(MBNonZero));
  Value *ZeroTimesInf = B.CreateOr(B.CreateAnd(AIsZero, BIsInf),
                                   B.CreateAnd(BIsZero, AIsInf));
  Value *EitherNaN = B.CreateOr(AIsNaN, BIsNaN);
  Value *NaNCase = B.CreateOr(EitherNaN, ZeroTimesInf);
  Value *AnyInf = B.CreateOr(AIsInf, BIsInf);
  Value *MulInfBits = B.CreateOr(SignField, C64(0x7FF0000000000000ull));

  Result = B.CreateSelect(AnyInf, MulInfBits, Result);
  Result = B.CreateSelect(NaNCase, C64(0x7FF8000000000000ull), Result);

  B.CreateRet(B.CreateBitCast(Result, F64));
}

// Stage 7h6 — `__divdf3 (a, b) -> double`. IEEE-754 double-precision
// divide. Mirrors stage-7g3 `__divsf3` widened to f64's 53-bit
// mantissa: a 52-iter restoring long-division loop with real
// CondBr / PHI control flow, operating over i64 values.
//
// Algorithm:
//   1. Extract sign / exp / mant from both inputs; result sign =
//      sa XOR sb; either-zero detection (exp == 0 ⇒ flush-to-zero
//      treatment of the input).
//   2. Initial renormalize: if ma < mb, shift ma left by 1 (so
//      ma_norm ∈ [mb, 2*mb)) and decrement the result exponent.
//   3. Long-division loop, 52 iterations producing 52 fractional
//      bits below the implicit-1:
//        r = ma_norm - mb        // residue in [0, mb)
//        q = 1                   // implicit-1
//        for i in 52..1:
//          r <<= 1
//          q <<= 1
//          if r >= mb: r -= mb; q |= 1
//   4. One extra guard step, sticky from residue, RNTE round, exp
//      bump on rounding overflow.
//   5. Pack {sr, er, mant}; special cases: a == 0 ⇒ signed zero,
//      b == 0 ⇒ signed Inf, 0/0 ⇒ NaN, Inf/Inf ⇒ NaN, Inf/finite
//      ⇒ signed Inf, finite/Inf ⇒ signed zero, NaN input ⇒ qNaN.
//
// The loop-body i64 selects (r / q updates) get rewritten to bit-
// blends by the SELECT → bit-blend pass (helper-safe attribute);
// the loop control itself (CondBr / PHI) survives into the lowered
// MIR with coarse-grained branching, matching `__divsf3`'s shape.
// i64 compares inside the body use the manual {hi, lo} i32-pair
// pattern from stage-7h4 to avoid DAG-ISel multi-minute pathology
// with `icmp uge i64`.
static void injectDivDf3Helper(Module &M, LLVMContext &Ctx) {
  Type *F64 = Type::getDoubleTy(Ctx);
  Type *I32 = Type::getInt32Ty(Ctx);
  Type *I64 = Type::getInt64Ty(Ctx);
  FunctionType *FnTy = FunctionType::get(F64, {F64, F64}, /*isVarArg=*/false);

  Function *F = makeOrPromoteHelper(M, "__divdf3", FnTy);
  if (!F)
    return;

  F->getArg(0)->setName("a");
  F->getArg(1)->setName("b");

  BasicBlock *Entry = BasicBlock::Create(Ctx, "entry", F);
  BasicBlock *Loop = BasicBlock::Create(Ctx, "loop", F);
  BasicBlock *Exit = BasicBlock::Create(Ctx, "exit", F);

  // === entry ===
  IRBuilder<> B(Entry);
  auto C64 = [&](uint64_t V) { return ConstantInt::get(I64, V); };
  auto C32 = [&](uint32_t V) { return ConstantInt::get(I32, V); };

  Value *AI = B.CreateBitCast(F->getArg(0), I64, "ai");
  Value *BI = B.CreateBitCast(F->getArg(1), I64, "bi");

  // i32-pair compare helpers (same shape as 7h4 / 7h5).
  auto SplitLoHi = [&](IRBuilder<> &Bld, Value *X)
      -> std::pair<Value *, Value *> {
    Value *Hi = Bld.CreateTrunc(Bld.CreateLShr(X, C64(32)), I32);
    Value *Lo = Bld.CreateTrunc(X, I32);
    return {Lo, Hi};
  };
  auto IsNonZeroI64 = [&](IRBuilder<> &Bld, Value *X) {
    auto [Lo, Hi] = SplitLoHi(Bld, X);
    return Bld.CreateOr(Bld.CreateICmpNE(Lo, C32(0)),
                        Bld.CreateICmpNE(Hi, C32(0)));
  };
  auto UltI64 = [&](IRBuilder<> &Bld, Value *Av, Value *Bv) {
    auto [aLo, aHi] = SplitLoHi(Bld, Av);
    auto [bLo, bHi] = SplitLoHi(Bld, Bv);
    Value *HiLt = Bld.CreateICmpULT(aHi, bHi);
    Value *HiEq = Bld.CreateICmpEQ(aHi, bHi);
    Value *LoLt = Bld.CreateICmpULT(aLo, bLo);
    return Bld.CreateOr(HiLt, Bld.CreateAnd(HiEq, LoLt));
  };
  auto UgeI64 = [&](IRBuilder<> &Bld, Value *Av, Value *Bv) {
    return Bld.CreateNot(UltI64(Bld, Av, Bv));
  };

  // Field extraction.
  Value *SA = B.CreateLShr(AI, C64(63));
  Value *SB = B.CreateLShr(BI, C64(63));
  Value *EA64 = B.CreateAnd(B.CreateLShr(AI, C64(52)), C64(0x7FFull));
  Value *EB64 = B.CreateAnd(B.CreateLShr(BI, C64(52)), C64(0x7FFull));
  Value *EA = B.CreateTrunc(EA64, I32, "ea");
  Value *EB = B.CreateTrunc(EB64, I32, "eb");
  Value *MARaw = B.CreateAnd(AI, C64(0xFFFFFFFFFFFFFull));
  Value *MBRaw = B.CreateAnd(BI, C64(0xFFFFFFFFFFFFFull));

  // Result sign.
  Value *SR = B.CreateXor(SA, SB);

  // Special-case detection.
  Value *AIsZero = B.CreateICmpEQ(EA, C32(0));
  Value *BIsZero = B.CreateICmpEQ(EB, C32(0));

  // Implicit-1.
  Value *MA = B.CreateOr(MARaw, C64(0x10000000000000ull));
  Value *MB = B.CreateOr(MBRaw, C64(0x10000000000000ull));

  // Initial renormalize. If ma < mb: ma_norm = ma << 1, er -= 1.
  Value *InitialRenorm = UltI64(B, MA, MB);
  Value *MANorm = B.CreateSelect(InitialRenorm, B.CreateShl(MA, C64(1)), MA);

  // Result exponent. ER = EA - EB + 1023 (- 1 if renormed).
  Value *ER0 = B.CreateAdd(B.CreateSub(EA, EB), C32(1023u));
  Value *ER = B.CreateSelect(InitialRenorm,
                             B.CreateSub(ER0, C32(1u)), ER0, "er");

  // Initial loop state: r0 = ma_norm - mb (in [0, mb)), q0 = 1.
  Value *R0 = B.CreateSub(MANorm, MB);
  Value *Q0 = C64(1);

  B.CreateBr(Loop);

  // === loop ===
  B.SetInsertPoint(Loop);
  PHINode *IPhi = B.CreatePHI(I32, 2, "i");
  PHINode *RPhi = B.CreatePHI(I64, 2, "r");
  PHINode *QPhi = B.CreatePHI(I64, 2, "q");
  IPhi->addIncoming(C32(52u), Entry);
  RPhi->addIncoming(R0, Entry);
  QPhi->addIncoming(Q0, Entry);

  Value *RShifted = B.CreateShl(RPhi, C64(1));
  Value *QShifted = B.CreateShl(QPhi, C64(1));
  Value *Take = UgeI64(B, RShifted, MB);
  Value *RSub = B.CreateSub(RShifted, MB);
  Value *QSet = B.CreateOr(QShifted, C64(1));
  Value *RNext = B.CreateSelect(Take, RSub, RShifted);
  Value *QNext = B.CreateSelect(Take, QSet, QShifted);
  Value *INext = B.CreateSub(IPhi, C32(1));
  Value *Done = B.CreateICmpEQ(INext, C32(0));
  B.CreateCondBr(Done, Exit, Loop);
  IPhi->addIncoming(INext, Loop);
  RPhi->addIncoming(RNext, Loop);
  QPhi->addIncoming(QNext, Loop);

  // === exit ===
  B.SetInsertPoint(Exit);
  PHINode *RExit = B.CreatePHI(I64, 1, "r_out");
  PHINode *QExit = B.CreatePHI(I64, 1, "q_out");
  RExit->addIncoming(RNext, Loop);
  QExit->addIncoming(QNext, Loop);

  // Guard bit: one extra long-division step on the residue.
  Value *RGuardRaw = B.CreateShl(RExit, C64(1));
  Value *GuardTake = UgeI64(B, RGuardRaw, MB);
  Value *GuardBit = B.CreateZExt(GuardTake, I64);
  Value *RAfterGuard = B.CreateSelect(GuardTake,
                                      B.CreateSub(RGuardRaw, MB),
                                      RGuardRaw);
  Value *StickyI1 = IsNonZeroI64(B, RAfterGuard);
  Value *Sticky = B.CreateZExt(StickyI1, I64);

  Value *Lsb = B.CreateAnd(QExit, C64(1u));
  Value *RoundUp = B.CreateAnd(GuardBit, B.CreateOr(Sticky, Lsb));
  Value *QRounded = B.CreateAdd(QExit, RoundUp);
  // RoundedOvf check via i32-pair compare for `q_rounded == 1 << 53`.
  auto EqI64Const = [&](Value *X, uint64_t K) {
    auto [Lo, Hi] = SplitLoHi(B, X);
    return B.CreateAnd(
        B.CreateICmpEQ(Hi, C32(static_cast<uint32_t>(K >> 32))),
        B.CreateICmpEQ(Lo, C32(static_cast<uint32_t>(K))));
  };
  Value *RoundOvf = EqI64Const(QRounded, 1ULL << 53);
  Value *QFinal = B.CreateSelect(RoundOvf,
                                 B.CreateLShr(QRounded, C64(1)),
                                 QRounded, "q_final");
  Value *ERFinal = B.CreateSelect(RoundOvf,
                                  B.CreateAdd(ER, C32(1u)), ER, "er_final");

  // Pack.
  Value *MantField = B.CreateAnd(QFinal, C64(0xFFFFFFFFFFFFFull));
  Value *ERFinal64 = B.CreateZExt(ERFinal, I64);
  Value *ExpField = B.CreateAnd(B.CreateShl(ERFinal64, C64(52)),
                                C64(0x7FF0000000000000ull));
  Value *SignField = B.CreateShl(SR, C64(63));
  Value *Packed = B.CreateOr(SignField,
                             B.CreateOr(ExpField, MantField));

  // Result-exponent gates.
  Value *Underflow = B.CreateICmpSLE(ERFinal, C32(0), "underflow");
  Value *Overflow = B.CreateICmpSGE(ERFinal, C32(2047), "overflow");
  Value *SignedZero = SignField;
  Value *SignedInf = B.CreateOr(SignField, C64(0x7FF0000000000000ull));

  Value *Result = B.CreateSelect(Overflow, SignedInf, Packed);
  Result = B.CreateSelect(Underflow, SignedZero, Result);
  // Divisor-zero wins over dividend-zero (so 0/0 starts as Inf;
  // the NaN gate below upgrades it to qNaN).
  Result = B.CreateSelect(AIsZero, SignedZero, Result);
  Result = B.CreateSelect(BIsZero, SignedInf, Result);

  // Stage 7g4 / 7h2 / 7h4-style Inf / NaN propagation:
  //   - NaN input             → canonical qNaN
  //   - Inf / Inf, 0 / 0      → NaN
  //   - Inf / finite (≠ 0)    → signed Inf with sr
  //   - finite / Inf          → signed zero with sr
  Value *EAMax = B.CreateICmpEQ(EA, C32(0x7FFu));
  Value *EBMax = B.CreateICmpEQ(EB, C32(0x7FFu));
  Value *MANonZero = IsNonZeroI64(B, MARaw);
  Value *MBNonZero = IsNonZeroI64(B, MBRaw);
  Value *AIsNaN = B.CreateAnd(EAMax, MANonZero);
  Value *BIsNaN = B.CreateAnd(EBMax, MBNonZero);
  Value *AIsInf = B.CreateAnd(EAMax, B.CreateNot(MANonZero));
  Value *BIsInf = B.CreateAnd(EBMax, B.CreateNot(MBNonZero));
  Value *BothInf = B.CreateAnd(AIsInf, BIsInf);
  Value *BothZero = B.CreateAnd(AIsZero, BIsZero);
  Value *EitherNaN = B.CreateOr(AIsNaN, BIsNaN);
  Value *NaNCase = B.CreateOr(EitherNaN,
                              B.CreateOr(BothInf, BothZero));

  Value *AInfBFinite = B.CreateAnd(AIsInf,
                                   B.CreateNot(B.CreateOr(BIsInf, BIsNaN)));
  Value *BInfAFinite = B.CreateAnd(BIsInf,
                                   B.CreateNot(B.CreateOr(AIsInf, AIsNaN)));

  Result = B.CreateSelect(AInfBFinite, SignedInf, Result);
  Result = B.CreateSelect(BInfAFinite, SignedZero, Result);
  Result = B.CreateSelect(NaNCase, C64(0x7FF8000000000000ull), Result);

  B.CreateRet(B.CreateBitCast(Result, F64));
}

// Stage 7h1 — `__extendsfdf2 (float a) -> double`. Lossless f32 → f64
// conversion. Algorithm:
//   - decode {sign, exp32, mant32_raw} from the f32 bit pattern
//   - exp64 = (exp32 == 0xFF)        ? 0x7FF                  (Inf/NaN)
//             : exp32 + 896          (= 1023 - 127 + exp32)   (normal)
//   - mant64 = mant32_raw << 29      (align bit 22 ↦ bit 51)
//   - pack (sign << 63) | (exp64 << 52) | mant64 as i64
//   - if exp32 == 0 (f32 zero or denormal) → flush to signed-zero f64
//
// The 7g0 flush-to-zero scope is preserved here: f32 denormal inputs
// land as f64 zero. Real IEEE would re-normalize (f32 denormals are
// all f64 normals since the exponent range is much wider) — out of
// scope alongside the f32 helpers.
//
// All i64 shifts are by *constant* amounts, so this body stays inside
// the current backend without needing a runtime i64 shift libcall
// (see `Cannot select shl_parts` probe).
static void injectExtendSfDf2Helper(Module &M, LLVMContext &Ctx) {
  Type *F32 = Type::getFloatTy(Ctx);
  Type *F64 = Type::getDoubleTy(Ctx);
  Type *I32 = Type::getInt32Ty(Ctx);
  Type *I64 = Type::getInt64Ty(Ctx);
  FunctionType *FnTy = FunctionType::get(F64, {F32}, /*isVarArg=*/false);

  Function *F = makeOrPromoteHelper(M, "__extendsfdf2", FnTy);
  if (!F)
    return;
  F->getArg(0)->setName("a");

  BasicBlock *Entry = BasicBlock::Create(Ctx, "entry", F);
  IRBuilder<> B(Entry);
  auto C32 = [&](uint32_t V) { return B.getInt32(V); };
  auto C64 = [&](uint64_t V) { return B.getInt64(V); };

  Value *AI = B.CreateBitCast(F->getArg(0), I32, "ai");
  Value *Sign32 = B.CreateLShr(AI, C32(31), "sign32");
  Value *Exp32 = B.CreateAnd(B.CreateLShr(AI, C32(23)), C32(0xFFu), "exp32");
  Value *MantRaw = B.CreateAnd(AI, C32(0x7FFFFFu), "mant_raw");

  Value *Sign64 = B.CreateZExt(Sign32, I64);
  Value *Mant64 = B.CreateShl(B.CreateZExt(MantRaw, I64), C64(29), "mant64");

  // Normal exp rebias: f64 = f32 + (1023 - 127) = f32 + 896. Inf/NaN
  // jumps the rebias and writes 0x7FF directly.
  Value *Exp32IsMax = B.CreateICmpEQ(Exp32, C32(0xFFu));
  Value *Exp64Normal = B.CreateZExt(B.CreateAdd(Exp32, C32(896u)), I64);
  Value *Exp64 = B.CreateSelect(Exp32IsMax, C64(0x7FFull), Exp64Normal,
                                "exp64");

  // Pack {sign(63), exp(62..52), mant(51..0)}.
  Value *SignField = B.CreateShl(Sign64, C64(63));
  Value *ExpField = B.CreateShl(Exp64, C64(52));
  Value *Packed = B.CreateOr(SignField,
                             B.CreateOr(ExpField, Mant64));

  // Flush zero / denormal to signed zero (no re-normalize).
  Value *Exp32IsZero = B.CreateICmpEQ(Exp32, C32(0u));
  Value *SignedZero = SignField;
  Value *Result = B.CreateSelect(Exp32IsZero, SignedZero, Packed);

  B.CreateRet(B.CreateBitCast(Result, F64));
}

// Stage 7h1 — `__truncdfsf2 (double a) -> float`. f64 → f32 truncation
// with round-to-nearest-ties-to-even. Algorithm:
//   - decode {sign, exp64, mant_top, mant_bot} from the i64 bit
//     pattern, splitting the 52-bit f64 mantissa across an upper
//     20-bit half (in di_hi[19:0]) and a lower 32-bit half (in di_lo).
//   - exp32 = exp64 - 896                    (rebias)
//   - mant_f32_raw_24 = (mant_top << 3) | (mant_bot >> 29)    (top 23
//                                                              bits +
//                                                              one
//                                                              extra
//                                                              for the
//                                                              implicit
//                                                              1)
//   - guard = (mant_bot >> 28) & 1
//   - sticky = (mant_bot & 0x0FFFFFFF) != 0
//   - round-to-nearest-ties-to-even, with mantissa-overflow bump
//   - special cases:
//       exp64 == 0x7FF  → mant_nonzero ? canonical qNaN f32 : signed Inf
//       exp64 == 0      → signed zero f32
//       exp32 ≤ 0       → flush to signed zero (no f32 denormal output)
//       exp32 ≥ 255     → signed Inf
//
// All i64 shifts are by 32 (constant), so this body also stays inside
// the current backend without a runtime i64 shift libcall.
static void injectTruncDfSf2Helper(Module &M, LLVMContext &Ctx) {
  Type *F32 = Type::getFloatTy(Ctx);
  Type *F64 = Type::getDoubleTy(Ctx);
  Type *I32 = Type::getInt32Ty(Ctx);
  Type *I64 = Type::getInt64Ty(Ctx);
  FunctionType *FnTy = FunctionType::get(F32, {F64}, /*isVarArg=*/false);

  Function *F = makeOrPromoteHelper(M, "__truncdfsf2", FnTy);
  if (!F)
    return;
  F->getArg(0)->setName("a");

  BasicBlock *Entry = BasicBlock::Create(Ctx, "entry", F);
  IRBuilder<> B(Entry);
  auto C32 = [&](uint32_t V) { return B.getInt32(V); };

  Value *DI = B.CreateBitCast(F->getArg(0), I64, "di");
  Value *DHi64 = B.CreateLShr(DI, B.getInt64(32));
  Value *DHi = B.CreateTrunc(DHi64, I32, "di_hi");
  Value *DLo = B.CreateTrunc(DI, I32, "di_lo");

  // Field extraction from di_hi: bit 31 sign, bits 30..20 exp,
  // bits 19..0 top-20-bits of the 52-bit mantissa.
  Value *Sign = B.CreateLShr(DHi, C32(31));
  Value *Exp64 = B.CreateAnd(B.CreateLShr(DHi, C32(20)), C32(0x7FFu));
  Value *MantTop = B.CreateAnd(DHi, C32(0xFFFFFu));   // bits 51..32
  Value *MantBot = DLo;                                // bits 31..0

  // f32 mantissa = top 23 bits of the 52-bit mantissa, with the
  // implicit-1 conceptually at bit 23 of the resulting 24-bit value.
  // Build the 24-bit "mantissa with implicit-1" first:
  //   m24 = 1<<23 | (top 23 bits)
  //       = ((MantTop | 0x100000) << 3) | (MantBot >> 29)
  Value *MantTopHidden = B.CreateOr(MantTop, C32(0x100000u));
  Value *M24 = B.CreateOr(B.CreateShl(MantTopHidden, C32(3)),
                          B.CreateLShr(MantBot, C32(29)));

  // Rounding bits live in the dropped low region: bit 28 of MantBot
  // is the guard, bits 27..0 of MantBot are the sticky source.
  Value *Guard = B.CreateAnd(B.CreateLShr(MantBot, C32(28)), C32(1u));
  Value *StickyNZ = B.CreateICmpNE(B.CreateAnd(MantBot, C32(0x0FFFFFFFu)),
                                   C32(0u));
  Value *Sticky = B.CreateZExt(StickyNZ, I32);
  Value *Lsb = B.CreateAnd(M24, C32(1u));
  Value *RoundUp = B.CreateAnd(Guard, B.CreateOr(Sticky, Lsb));
  Value *M24Rounded = B.CreateAdd(M24, RoundUp);
  // Rounding may push m24 to 0x1000000 ⇒ shift right and bump exp.
  Value *RoundOvf = B.CreateICmpEQ(M24Rounded, C32(0x1000000u));
  Value *M24Final = B.CreateSelect(RoundOvf,
                                   B.CreateLShr(M24Rounded, C32(1)),
                                   M24Rounded);

  // Exponent rebias. f32 = f64 - (1023 - 127) = f64 - 896. Tracked as
  // signed i32 so the underflow gate works on negative values.
  Value *Exp32Pre = B.CreateSub(Exp64, C32(896u));
  Value *Exp32 = B.CreateSelect(RoundOvf,
                                B.CreateAdd(Exp32Pre, C32(1u)),
                                Exp32Pre);

  // Pack the normal f32 result.
  Value *MantField = B.CreateAnd(M24Final, C32(0x7FFFFFu));
  Value *ExpField = B.CreateAnd(B.CreateShl(Exp32, C32(23)),
                                C32(0x7F800000u));
  Value *SignField = B.CreateShl(Sign, C32(31));
  Value *Packed = B.CreateOr(SignField,
                             B.CreateOr(ExpField, MantField));

  Value *SignedZero = SignField;
  Value *SignedInf = B.CreateOr(SignField, C32(0x7F800000u));

  // Overflow / underflow on the f32 side. Use signed comparisons so
  // out-of-range f64 values (which wrap exp32 around into the high
  // unsigned range) trigger the right gate.
  Value *Overflow = B.CreateICmpSGE(Exp32, C32(255u));
  Value *Underflow = B.CreateICmpSLE(Exp32, C32(0u));
  Value *Result = B.CreateSelect(Overflow, SignedInf, Packed);
  Result = B.CreateSelect(Underflow, SignedZero, Result);

  // f64 special cases override the rebias/rounding path.
  Value *MantNonzero = B.CreateOr(B.CreateICmpNE(MantTop, C32(0u)),
                                  B.CreateICmpNE(MantBot, C32(0u)));
  Value *Exp64IsMax = B.CreateICmpEQ(Exp64, C32(0x7FFu));
  Value *AIsNaN = B.CreateAnd(Exp64IsMax, MantNonzero);
  Value *AIsInf = B.CreateAnd(Exp64IsMax, B.CreateNot(MantNonzero));
  Value *Exp64IsZero = B.CreateICmpEQ(Exp64, C32(0u));

  Result = B.CreateSelect(AIsInf, SignedInf, Result);
  Result = B.CreateSelect(AIsNaN, C32(0x7FC00000u), Result);
  Result = B.CreateSelect(Exp64IsZero, SignedZero, Result);

  B.CreateRet(B.CreateBitCast(Result, F32));
}

// Convenience scan over the entire f32 operation set this stage
// covers. Mirrors `moduleNeedsAddSf3Helper` but is permissive over
// any FP / int↔FP IR construct that's expected to lower into one of
// our injected libcalls.
static bool moduleNeedsF32Helpers(Module &M) {
  for (Function &F : M) {
    if (F.isDeclaration())
      continue;
    for (Instruction &I : instructions(F)) {
      switch (I.getOpcode()) {
      case Instruction::FAdd:
      case Instruction::FSub:
      case Instruction::FMul:
      case Instruction::FDiv:
      case Instruction::FCmp:
        if (I.getOperand(0)->getType()->getScalarType()->isFloatTy())
          return true;
        break;
      case Instruction::SIToFP:
      case Instruction::UIToFP:
        if (I.getType()->getScalarType()->isFloatTy() &&
            I.getOperand(0)->getType()->getScalarType()->isIntegerTy(32))
          return true;
        break;
      case Instruction::FPToSI:
      case Instruction::FPToUI:
        if (I.getOperand(0)->getType()->getScalarType()->isFloatTy() &&
            I.getType()->getScalarType()->isIntegerTy(32))
          return true;
        break;
      default:
        break;
      }
    }
  }
  return false;
}

// Per-helper gate for `__mulsf3` so an `fadd`-only (or `fcmp`-only,
// etc.) module does not pay for the 24x24 mantissa multiply body. The
// other helpers stay on the broad `moduleNeedsF32Helpers` gate for
// now: they pull each other in (e.g. fsub→fadd) or share a body
// (fcmp set), and their generated size is materially smaller than
// `__mulsf3`'s inlined byte-table multiplies.
static bool moduleNeedsMulSf3(Module &M) {
  for (Function &F : M) {
    if (F.isDeclaration())
      continue;
    for (Instruction &I : instructions(F)) {
      if (I.getOpcode() == Instruction::FMul &&
          I.getOperand(0)->getType()->getScalarType()->isFloatTy())
        return true;
    }
  }
  return false;
}

// Per-helper gate for `__divsf3` — same reasoning as `__mulsf3`. The
// 23-iter long-division loop + guard / sticky body is materially
// larger than the straight-line helpers, so an `fadd`-only module
// shouldn't pay for it.
static bool moduleNeedsDivSf3(Module &M) {
  for (Function &F : M) {
    if (F.isDeclaration())
      continue;
    for (Instruction &I : instructions(F)) {
      if (I.getOpcode() == Instruction::FDiv &&
          I.getOperand(0)->getType()->getScalarType()->isFloatTy())
        return true;
    }
  }
  return false;
}

// Stage 7h1 — fpext / fptrunc gates. Each is independent of the
// other f32 helpers and only fires when the corresponding cast
// appears in the module.
static bool moduleNeedsExtendSfDf2(Module &M) {
  for (Function &F : M) {
    if (F.isDeclaration())
      continue;
    for (Instruction &I : instructions(F)) {
      if (I.getOpcode() == Instruction::FPExt &&
          I.getOperand(0)->getType()->getScalarType()->isFloatTy() &&
          I.getType()->getScalarType()->isDoubleTy())
        return true;
    }
  }
  return false;
}

static bool moduleNeedsTruncDfSf2(Module &M) {
  for (Function &F : M) {
    if (F.isDeclaration())
      continue;
    for (Instruction &I : instructions(F)) {
      if (I.getOpcode() == Instruction::FPTrunc &&
          I.getOperand(0)->getType()->getScalarType()->isDoubleTy() &&
          I.getType()->getScalarType()->isFloatTy())
        return true;
    }
  }
  return false;
}

// Stage 7h2 — scan for `fcmp double` (any predicate) so the f64
// compare helpers are only injected when actually used.
static bool moduleNeedsDoubleCompare(Module &M) {
  for (Function &F : M) {
    if (F.isDeclaration())
      continue;
    for (Instruction &I : instructions(F)) {
      if (I.getOpcode() == Instruction::FCmp &&
          I.getOperand(0)->getType()->getScalarType()->isDoubleTy())
        return true;
    }
  }
  return false;
}

// Stage 7h3 — scan for sitofp / uitofp into double.
static bool moduleNeedsFloatsidf(Module &M) {
  for (Function &F : M) {
    if (F.isDeclaration())
      continue;
    for (Instruction &I : instructions(F)) {
      if ((I.getOpcode() == Instruction::SIToFP ||
           I.getOpcode() == Instruction::UIToFP) &&
          I.getType()->getScalarType()->isDoubleTy() &&
          I.getOperand(0)->getType()->getScalarType()->isIntegerTy(32))
        return true;
    }
  }
  return false;
}

// Stage 7h3 — scan for fptosi / fptoui from double to i32.
static bool moduleNeedsFixdfsi(Module &M) {
  for (Function &F : M) {
    if (F.isDeclaration())
      continue;
    for (Instruction &I : instructions(F)) {
      if ((I.getOpcode() == Instruction::FPToSI ||
           I.getOpcode() == Instruction::FPToUI) &&
          I.getOperand(0)->getType()->getScalarType()->isDoubleTy() &&
          I.getType()->getScalarType()->isIntegerTy(32))
        return true;
    }
  }
  return false;
}

// Stage 7h9 — scan for sitofp / uitofp from i64 to double.
static bool moduleNeedsFloatdidf(Module &M) {
  for (Function &F : M) {
    if (F.isDeclaration())
      continue;
    for (Instruction &I : instructions(F)) {
      if ((I.getOpcode() == Instruction::SIToFP ||
           I.getOpcode() == Instruction::UIToFP) &&
          I.getType()->getScalarType()->isDoubleTy() &&
          I.getOperand(0)->getType()->getScalarType()->isIntegerTy(64))
        return true;
    }
  }
  return false;
}

// Stage 7h9 — scan for fptosi / fptoui from double to i64.
static bool moduleNeedsFixdfdi(Module &M) {
  for (Function &F : M) {
    if (F.isDeclaration())
      continue;
    for (Instruction &I : instructions(F)) {
      if ((I.getOpcode() == Instruction::FPToSI ||
           I.getOpcode() == Instruction::FPToUI) &&
          I.getOperand(0)->getType()->getScalarType()->isDoubleTy() &&
          I.getType()->getScalarType()->isIntegerTy(64))
        return true;
    }
  }
  return false;
}

// Stage 7h4 — scan for `fadd double` / `fsub double`.
static bool moduleNeedsAddDf3(Module &M) {
  for (Function &F : M) {
    if (F.isDeclaration())
      continue;
    for (Instruction &I : instructions(F)) {
      if ((I.getOpcode() == Instruction::FAdd ||
           I.getOpcode() == Instruction::FSub) &&
          I.getOperand(0)->getType()->getScalarType()->isDoubleTy())
        return true;
    }
  }
  return false;
}

// Stage 7h5 — scan for `fmul double`.
static bool moduleNeedsMulDf3(Module &M) {
  for (Function &F : M) {
    if (F.isDeclaration())
      continue;
    for (Instruction &I : instructions(F)) {
      if (I.getOpcode() == Instruction::FMul &&
          I.getOperand(0)->getType()->getScalarType()->isDoubleTy())
        return true;
    }
  }
  return false;
}

// Stage 7h6 — scan for `fdiv double`.
static bool moduleNeedsDivDf3(Module &M) {
  for (Function &F : M) {
    if (F.isDeclaration())
      continue;
    for (Instruction &I : instructions(F)) {
      if (I.getOpcode() == Instruction::FDiv &&
          I.getOperand(0)->getType()->getScalarType()->isDoubleTy())
        return true;
    }
  }
  return false;
}

int main(int argc, char **argv) {
  InitLLVM X(argc, argv);

  // Register our backend with the global registry. Same pattern llc uses,
  // just narrowed to the one target we care about.
  LLVMInitializeMovTargetInfo();
  LLVMInitializeMovTarget();
  LLVMInitializeMovTargetMC();
  LLVMInitializeMovAsmPrinter();

  // Stage 6d1 — register the LLVM Scalarizer legacy pass + its
  // analysis dependencies (DominatorTree, ScalarOpts group,
  // TransformUtils, Analysis) on the global registry. Without
  // these, `PassManager::run` aborts with "Required pass not
  // found" when the driver-level IR pre-pass below adds Scalarizer.
  PassRegistry &Reg = *PassRegistry::getPassRegistry();
  initializeCore(Reg);
  initializeAnalysis(Reg);
  initializeTransformUtils(Reg);
  initializeScalarOpts(Reg);
  initializeScalarizerLegacyPassPass(Reg);

  cl::ParseCommandLineOptions(argc, argv,
                              "llvm-mov-llc — .ll -> mov-target asm\n");

  LLVMContext Ctx;
  SMDiagnostic Err;
  std::unique_ptr<Module> M = parseIRFile(InputFilename, Err, Ctx);
  if (!M) {
    Err.print(argv[0], errs());
    return 1;
  }

  // Resolve the effective triple. Three sources, in priority order:
  //   1. explicit -mtriple on the command line   (the user is *retargeting*)
  //   2. the input module's `target triple = "..."`  (we trust it implicitly)
  //   3. the cl::opt default ("mov-unknown-linux-gnu")
  //
  // The implicit vs. explicit distinction matters for the layout check
  // below: if the user explicitly passed -mtriple, they're asking us to
  // retarget — datalayout mismatch is expected and we should overwrite.
  // If they didn't, we're trusting the module, and any mismatch points to
  // a frontend that handed us an incompatible module — we refuse.
  const bool TripleWasExplicit = MTriple.getNumOccurrences() > 0;
  Triple TheTriple;
  if (TripleWasExplicit) {
    TheTriple = Triple(MTriple);
  } else if (!M->getTargetTriple().str().empty()) {
    TheTriple = M->getTargetTriple();
  } else {
    TheTriple = Triple(MTriple); // cl::opt default
  }

  // The arch *name* is the authoritative identifier — `getArch()` falls
  // back to `Triple::UnknownArch` for anything it doesn't recognise (like
  // typoed `movv-...`), which would otherwise let malformed triples
  // through.
  if (TheTriple.getArchName() != "mov") {
    WithColor::error(errs(), argv[0])
        << "triple '" << TheTriple.str()
        << "' is not a Mov triple; pass -mtriple=mov-... to override.\n";
    return 1;
  }

  std::string ErrorString;
  const Target *TheTarget =
      TargetRegistry::lookupTarget(/*ArchName=*/"mov", TheTriple, ErrorString);
  if (!TheTarget) {
    WithColor::error(errs(), argv[0]) << ErrorString;
    return 1;
  }

  TargetOptions Options;
  std::unique_ptr<TargetMachine> TM(TheTarget->createTargetMachine(
      TheTriple, /*CPU=*/"", /*Features=*/"", Options,
      Reloc::Static, std::nullopt, CodeGenOptLevel::Default));
  if (!TM) {
    WithColor::error(errs(), argv[0]) << "could not allocate TargetMachine\n";
    return 1;
  }

  // Layout mismatch handling mirrors the triple logic:
  //   - implicit retargeting (no -mtriple): the module's layout claim is
  //     load-bearing, so we refuse on any divergence;
  //   - explicit retargeting (`-mtriple=mov-...`): the user is asking us
  //     to overwrite, so we just do it (and don't warn — it's the whole
  //     point of the flag).
  const std::string TargetLayout =
      TM->createDataLayout().getStringRepresentation();
  const std::string &ModuleLayout = M->getDataLayoutStr();
  if (!TripleWasExplicit && !ModuleLayout.empty() &&
      ModuleLayout != TargetLayout) {
    WithColor::error(errs(), argv[0])
        << "input module data layout '" << ModuleLayout
        << "' does not match the Mov target's '" << TargetLayout
        << "' (pass -mtriple=mov-... to force-retarget).\n";
    return 1;
  }
  M->setDataLayout(TM->createDataLayout());
  M->setTargetTriple(TheTriple);

  std::error_code EC;
  auto Out = std::make_unique<ToolOutputFile>(OutputFilename, EC,
                                              sys::fs::OF_None);
  if (EC) {
    WithColor::error(errs(), argv[0]) << EC.message() << "\n";
    return 1;
  }

  // Stage 7h8 — rewrite `llvm.fptosi.sat.*` / `llvm.fptoui.sat.*`
  // intrinsics into plain `fptosi` / `fptoui` instructions. Rust
  // 1.45+ emits these saturating intrinsics for `as iN` casts on
  // floats; SDAG's default Expand of them decomposes into a NaN /
  // range compare-cascade of libcall fcmps surrounded by selects,
  // which combines so badly with the i32 bit-blend that compilation
  // stalls (observed ≥ 9 min on the mandelbrot crate). Our injected
  // `__fixsfsi` / `__fixdfsi` / `__fixunssfsi` / `__fixunsdfsi`
  // helpers already saturate (out-of-range → INT_MIN / INT_MAX /
  // UINT_MAX, NaN → 0 as of this stage), so the saturating
  // semantics are preserved by routing through the regular FP→int
  // path. Doing the swap at the IR level sidesteps SDAG's soft-float
  // legalizer eagerly expanding the saturating node before any
  // Custom action can fire.
  for (Function &F : *M) {
    if (F.isDeclaration())
      continue;
    SmallVector<IntrinsicInst *, 4> SatCalls;
    for (Instruction &I : instructions(F)) {
      if (auto *II = dyn_cast<IntrinsicInst>(&I)) {
        Intrinsic::ID Id = II->getIntrinsicID();
        if (Id != Intrinsic::fptosi_sat && Id != Intrinsic::fptoui_sat)
          continue;
        // Codex-review P2 (stage 7h8): the "helper saturates to
        // INT_MIN/MAX/UINT_MAX" preservation argument holds for
        // result widths where the injected helper actually saturates
        // to the matching range — i32 (`__fix*si`) and (with stage
        // 7h9 wiring) i64 (`__fix*di`). Narrower destinations (`f32
        // as i8` etc.) need clamping to the destination's own range,
        // so leave those intrinsics in place and let SDAG's default
        // expansion handle them.
        Type *DstTy = II->getType();
        Type *SrcTy = II->getArgOperand(0)->getType();
        // Codex-review P1 (stage 7h9): only rewrite when the source
        // FP type has a wired helper for the destination width:
        //   - dst i32: `__fix*sfsi` (f32) / `__fix*dfsi` (f64)
        //   - dst i64: only `__fix*dfdi` (f64) is wired; f32→i64 has
        //             no libcall mapping, so leave that intrinsic
        //             to SDAG's default expansion.
        bool DstI32 = DstTy->isIntegerTy(32);
        bool DstI64 = DstTy->isIntegerTy(64);
        if (!DstI32 && !DstI64)
          continue;
        bool SrcF32 = SrcTy->isFloatTy();
        bool SrcF64 = SrcTy->isDoubleTy();
        if (DstI32 && !(SrcF32 || SrcF64))
          continue;
        if (DstI64 && !SrcF64)
          continue;
        SatCalls.push_back(II);
      }
    }
    for (IntrinsicInst *II : SatCalls) {
      IRBuilder<> B(II);
      Value *Src = II->getArgOperand(0);
      Type *DstTy = II->getType();
      Value *Replacement = (II->getIntrinsicID() == Intrinsic::fptosi_sat)
                               ? B.CreateFPToSI(Src, DstTy)
                               : B.CreateFPToUI(Src, DstTy);
      II->replaceAllUsesWith(Replacement);
      II->eraseFromParent();
    }
  }

  // Stage 7f2 — inject `__udivsi3 / __umodsi3 / __divsi3 / __modsi3`
  // bodies as IR. Must happen before the Function-level rewrite loop
  // below so the loop's SELECT → bit-blend / SExt-i1 rewrites also
  // apply to the helpers' i1-cond SELECTs. Without that rewrite, the
  // 32-iter loop with raw SELECTs would push DAG-ISel into the
  // multi-minute compile-time pathology that motivated the SELECT
  // rewrite in the first place (see the SELECT-rewrite comment
  // around stage 6d3e below).
  if (moduleNeedsDivRemHelpers(*M))
    injectDivRemHelpers(*M, Ctx);

  // Stage 7g1 — single-precision FP helper bodies. Each scan triggers
  // only when its respective IR op is present, so a module with no
  // f32 ops pays nothing in helper-body code. `__addsf3` lands first
  // because `__subsf3` delegates to it; fcmp / conversion bodies are
  // independent.
  if (moduleNeedsF32Helpers(*M)) {
    injectAddSf3Helper(*M, Ctx);
    injectSubSf3Helper(*M, Ctx);
    injectFloatCompareHelpers(*M, Ctx);
    injectFloatsisfHelpers(*M, Ctx);
    injectFixsfsiHelpers(*M, Ctx);
  }
  // `__mulsf3` is gated separately: its body is materially larger
  // than the other helpers because the 24x24 mantissa multiply pulls
  // in stage-7f1 byte-table multiplies for each of the four partials,
  // so emitting it on every `fadd`-only module would regress size.
  if (moduleNeedsMulSf3(*M))
    injectMulSf3Helper(*M, Ctx);
  // `__divsf3` similarly: its 23-iter long-division loop adds enough
  // body code that gating on actual `fdiv` use is worth the extra
  // scan.
  if (moduleNeedsDivSf3(*M))
    injectDivSf3Helper(*M, Ctx);
  // Stage 7h1 — fpext / fptrunc helpers. Independent of the f32
  // arithmetic gates; each fires only when the corresponding cast
  // actually appears in the module.
  if (moduleNeedsExtendSfDf2(*M))
    injectExtendSfDf2Helper(*M, Ctx);
  if (moduleNeedsTruncDfSf2(*M))
    injectTruncDfSf2Helper(*M, Ctx);
  // Stage 7h2 — f64 compare helpers. Independent of the conversion
  // helpers; only the modules that actually `fcmp double` pay for
  // the body.
  if (moduleNeedsDoubleCompare(*M))
    injectDoubleCompareHelpers(*M, Ctx);
  // Stage 7h3 — i32 ↔ f64 conversion helpers. Each gates on the
  // corresponding cast actually appearing in the module.
  if (moduleNeedsFloatsidf(*M))
    injectFloatsidfHelpers(*M, Ctx);
  if (moduleNeedsFixdfsi(*M))
    injectFixdfsiHelpers(*M, Ctx);
  if (moduleNeedsFloatdidf(*M))
    injectFloatdidfHelpers(*M, Ctx);
  if (moduleNeedsFixdfdi(*M))
    injectFixdfdiHelpers(*M, Ctx);
  // Stage 7h4 — f64 fadd / fsub. `__adddf3` first since `__subdf3`
  // tail-calls it.
  // Stage 7h5 — `__muldf3` gated separately like 7g2 `__mulsf3`. The
  // 53×53 → 106-bit mantissa multiply pulls in four 32×32 sub-
  // multiplies (each = 4 byte-table `mul i32`), so an fadd-only
  // module shouldn't pay for it.
  if (moduleNeedsMulDf3(*M))
    injectMulDf3Helper(*M, Ctx);
  // Stage 7h6 — `__divdf3` (52-iter loop body, gated separately
  // like the f32 7g3 `__divsf3`).
  if (moduleNeedsDivDf3(*M))
    injectDivDf3Helper(*M, Ctx);
  if (moduleNeedsAddDf3(*M)) {
    injectAddDf3Helper(*M, Ctx);
    injectSubDf3Helper(*M, Ctx);
  }

  // Stage 6d2 — pre-Scalarizer lowering of `llvm.vector.reduce.*`.
  //
  // LLVM's `expand-reductions` codegen pass would otherwise rewrite
  // these into a shufflevector + vector-binop tree, re-introducing
  // `<N x ty>` ops *after* our driver-level Scalarizer (6d1) ran.
  // Lowering the reductions to a balanced scalar tree up front lets
  // both Scalarizer (6d1) and the codegen pipeline see scalar-only
  // shapes.
  //
  // Only `xor` is handled today (the only kind the AES example
  // emits); extending to add / and / or / smin / smax etc. is a
  // 4-line addition each.
  for (Function &F : *M) {
    SmallVector<IntrinsicInst *, 4> Worklist;
    SmallVector<IntrinsicInst *, 4> AbsList;
    SmallVector<IntrinsicInst *, 4> UMinList;
    SmallVector<IntrinsicInst *, 4> UMaxList;
    SmallVector<IntrinsicInst *, 4> SMinList;
    SmallVector<IntrinsicInst *, 4> SMaxList;
    for (Instruction &I : instructions(F)) {
      if (auto *II = dyn_cast<IntrinsicInst>(&I)) {
        switch (II->getIntrinsicID()) {
        case Intrinsic::vector_reduce_xor:
        case Intrinsic::vector_reduce_add:
        case Intrinsic::vector_reduce_and:
        case Intrinsic::vector_reduce_or:
          Worklist.push_back(II);
          break;
        case Intrinsic::abs:
          if (II->getType()->isIntegerTy(32))
            AbsList.push_back(II);
          break;
        case Intrinsic::umin:
          if (II->getType()->isIntegerTy(32))
            UMinList.push_back(II);
          break;
        case Intrinsic::umax:
          if (II->getType()->isIntegerTy(32))
            UMaxList.push_back(II);
          break;
        case Intrinsic::smin:
          if (II->getType()->isIntegerTy(32))
            SMinList.push_back(II);
          break;
        case Intrinsic::smax:
          if (II->getType()->isIntegerTy(32))
            SMaxList.push_back(II);
          break;
        default:
          break;
        }
      }
    }
    // Branchless replacements for min / max / abs i32. Going
    // through the default Expand path turns each into a SELECT,
    // and SELECT is Expand too — that cascade lands in CMP +
    // Jcc + branch + PHI and feeds back into DAGCombine
    // combinatorically. Spelling out the branchless integer
    // tricks here keeps the IR in pure shift / and / or / add /
    // sub form which our SDAG path lowers in linear time.
    auto AddMask = [](IRBuilder<> &B, Value *X) {
      // sign = X >> 31 arithmetic-right; -1 if X<0 else 0.
      return B.CreateAShr(X, 31);
    };
    for (IntrinsicInst *II : AbsList) {
      IRBuilder<> B(II);
      Value *X    = II->getArgOperand(0);
      Value *Sign = AddMask(B, X);
      // (x ^ sign) - sign  -- branchless abs.
      Value *Xor  = B.CreateXor(X, Sign);
      Value *R    = B.CreateSub(Xor, Sign);
      II->replaceAllUsesWith(R);
      II->eraseFromParent();
    }
    auto BlendOnCmp = [](IRBuilder<> &B, Value *Cond, Value *T, Value *F) {
      // Branchless 2-way select on i1, written so the backend never
      // sees `sext i1 -> i32`. The target sets
      // ZeroOrOneBooleanContent, so we zext the condition to 0/1
      // first, then `0 - zext` to materialize the 0/-1 mask via
      // legal i32 arithmetic. Equivalent value to `sext(cond)` but
      // synthesised purely with SUB / AND / OR / XOR — codex review:
      // marking SIGN_EXTEND of an i1 SetCC result as anything
      // other than the target-canonical Expand routes through a
      // legalizer path that loops on this backend.
      Value *Z01  = B.CreateZExt(Cond, T->getType());
      Value *Zero = ConstantInt::get(T->getType(), 0);
      Value *M    = B.CreateSub(Zero, Z01);
      Value *NotM = B.CreateNot(M);
      return B.CreateOr(B.CreateAnd(T, M), B.CreateAnd(F, NotM));
    };
    for (IntrinsicInst *II : UMinList) {
      IRBuilder<> B(II);
      Value *A = II->getArgOperand(0), *C = II->getArgOperand(1);
      II->replaceAllUsesWith(BlendOnCmp(B, B.CreateICmpULT(A, C), A, C));
      II->eraseFromParent();
    }
    for (IntrinsicInst *II : UMaxList) {
      IRBuilder<> B(II);
      Value *A = II->getArgOperand(0), *C = II->getArgOperand(1);
      II->replaceAllUsesWith(BlendOnCmp(B, B.CreateICmpUGT(A, C), A, C));
      II->eraseFromParent();
    }
    for (IntrinsicInst *II : SMinList) {
      IRBuilder<> B(II);
      Value *A = II->getArgOperand(0), *C = II->getArgOperand(1);
      II->replaceAllUsesWith(BlendOnCmp(B, B.CreateICmpSLT(A, C), A, C));
      II->eraseFromParent();
    }
    for (IntrinsicInst *II : SMaxList) {
      IRBuilder<> B(II);
      Value *A = II->getArgOperand(0), *C = II->getArgOperand(1);
      II->replaceAllUsesWith(BlendOnCmp(B, B.CreateICmpSGT(A, C), A, C));
      II->eraseFromParent();
    }

    // Branchless rewrite of all i32 SelectInsts. The default SELECT
    // Expand action emits a CMP + branch + PHI scaffold whose
    // multiplied basic blocks on tight inner loops (e.g. the udiv
    // 32-iteration loop in our libcall stub) push DAG-ISel into
    // multi-minute compile times. Replacing each SELECT with the
    // bit-blend `(a & sext(c)) | (b & ~sext(c))` is functionally
    // identical, four extra i32 ops per site, and the resulting
    // graph is straight-line — DAG-ISel handles it in
    // milliseconds.
    //
    // Only i32 (always) and i64 (helper-only) SELECTs are rewritten;
    // i1 / pointer / aggregate SELECTs (e.g. ones SROA leaves around
    // for control flow synthesis) keep going through the default
    // Expand path.
    //
    // Stage 7h1 — i64 added so the `__extendsfdf2` body's i64-typed
    // selects (zero / Inf / NaN overrides at the tail) stay branchless.
    // Without this, a single `select i64` pushes DAG-ISel into the same
    // multi-minute pathology that motivated the i32 rewrite (observed
    // 3.7-hour hang on `f64_extend_inf.ll` during 7h1 bring-up). The
    // bit-blend operations (and/or/not/sub) all have native i64-to-i32-
    // pair lowerings, so the rewrite is functionally identical at i64.
    //
    // The i64 case is gated on the `llvm-mov-bit-blend-safe` function
    // attribute (set by `makeOrPromoteHelper` for every injected
    // helper). User-authored i64 selects keep default Expand because
    // bit-blend is unsafe when an unchosen arm is poison (e.g. from
    // an `nsw` overflow) — codex-review P2 on this stage's bring-up.
    const bool BitBlendSafe = F.hasFnAttribute(kBitBlendAttr);
    SmallVector<SelectInst *, 32> SelectList;
    for (Instruction &I : instructions(F))
      if (auto *S = dyn_cast<SelectInst>(&I))
        if (S->getType()->isIntegerTy(32) ||
            (BitBlendSafe && S->getType()->isIntegerTy(64)))
          SelectList.push_back(S);
    for (SelectInst *S : SelectList) {
      IRBuilder<> B(S);
      Value *Cond = S->getCondition();
      Value *T    = S->getTrueValue();
      Value *Fa   = S->getFalseValue();
      // Same blend shape as BlendOnCmp above — zext + sub to avoid
      // emitting `sext i1` (which dragged DAG-ISel into the
      // SETCC/SELECT_CC loop on the SDAG side).
      Value *Z01  = B.CreateZExt(Cond, T->getType());
      Value *Zero = ConstantInt::get(T->getType(), 0);
      Value *M    = B.CreateSub(Zero, Z01);
      Value *NotM = B.CreateNot(M);
      Value *R    = B.CreateOr(B.CreateAnd(T, M), B.CreateAnd(Fa, NotM));
      S->replaceAllUsesWith(R);
      S->eraseFromParent();
    }

    // Any remaining `sext i1 -> i32` instruction (e.g. from user IR
    // that wasn't routed through our SELECT rewrite) is rewritten
    // to `(0 - zext i1 cond to i32)`. The two are mathematically
    // identical — both produce -1 if cond is true, 0 otherwise — but
    // the zext+sub form keeps the backend on the i1→0/1 path the
    // legalizer / our Custom SETCC already handles. With sext-i1 the
    // SDAG legalizer goes through a sign-extending-SETCC path that
    // loops indefinitely with our SETCC/SELECT_CC actions.
    SmallVector<SExtInst *, 8> SExtList;
    for (Instruction &I : instructions(F))
      if (auto *SE = dyn_cast<SExtInst>(&I))
        if (SE->getSrcTy()->isIntegerTy(1) &&
            SE->getDestTy()->isIntegerTy(32))
          SExtList.push_back(SE);
    for (SExtInst *SE : SExtList) {
      IRBuilder<> B(SE);
      Value *Cond = SE->getOperand(0);
      Value *Z01  = B.CreateZExt(Cond, SE->getDestTy());
      Value *Zero = ConstantInt::get(SE->getDestTy(), 0);
      Value *R    = B.CreateSub(Zero, Z01);
      SE->replaceAllUsesWith(R);
      SE->eraseFromParent();
    }
    for (IntrinsicInst *II : Worklist) {
      Value *Vec = II->getArgOperand(0);
      auto *VecTy = cast<FixedVectorType>(Vec->getType());
      const unsigned N = VecTy->getNumElements();
      const Intrinsic::ID ID = II->getIntrinsicID();
      IRBuilder<> B(II);
      // Extract every element to a scalar, then fold to scalar as a
      // balanced binary tree. The fold op is chosen by intrinsic
      // kind. A linear chain would also be correct but a tree halves
      // the dependency depth (matters once each binop expands to
      // ~50 movs via the byte-chain mov-only legalize at stage 7).
      SmallVector<Value *, 32> Lanes;
      Lanes.reserve(N);
      for (unsigned i = 0; i < N; ++i)
        Lanes.push_back(B.CreateExtractElement(Vec, B.getInt32(i)));
      while (Lanes.size() > 1) {
        SmallVector<Value *, 32> Next;
        Next.reserve((Lanes.size() + 1) / 2);
        for (unsigned i = 0; i + 1 < Lanes.size(); i += 2) {
          Value *L = Lanes[i], *R = Lanes[i + 1];
          Value *Folded = nullptr;
          switch (ID) {
          case Intrinsic::vector_reduce_xor: Folded = B.CreateXor(L, R); break;
          case Intrinsic::vector_reduce_add: Folded = B.CreateAdd(L, R); break;
          case Intrinsic::vector_reduce_and: Folded = B.CreateAnd(L, R); break;
          case Intrinsic::vector_reduce_or:  Folded = B.CreateOr (L, R); break;
          default: llvm_unreachable("unreachable: kind filtered above");
          }
          Next.push_back(Folded);
        }
        if (Lanes.size() % 2)
          Next.push_back(Lanes.back());
        Lanes.swap(Next);
      }
      II->replaceAllUsesWith(Lanes[0]);
      II->eraseFromParent();
    }
  }

  // Stage 6d1 — pre-codegen IR scalarization.
  //
  // Rust crate IR ships `<N x ty>` vector ops (the `aes` crate's
  // block constants are `store <16 x i8>`, AES state is loaded as
  // `<16 x i8>`, etc.) that the DAG type legalizer can't split for
  // our strictly-scalar backend ("Do not know how to split the
  // result of this operator"). The built-in Scalarizer rewrites
  // each vector op into a chain of element-wise scalar ops; with
  // `ScalarizeLoadStore=true` it also expands vector loads and
  // stores into per-element scalar memory ops.
  //
  // We run it here as a dedicated FunctionPassManager on the IR
  // *before* `addPassesToEmitFile` adds the codegen pipeline.
  // Running it inside MovPassConfig::addIRPasses would technically
  // also work, but the LegacyPM TargetPassConfig already runs a
  // long fixed-order chain there. With reductions already lowered
  // above, the codegen-pipeline `expand-reductions` is a no-op so
  // running Scalarizer once here is enough.
  {
    legacy::PassManager IRPM;
    ScalarizerPassOptions Opts;
    Opts.ScalarizeMinBits   = 0;
    Opts.ScalarizeLoadStore = true;
    IRPM.add(createScalarizerPass(Opts));
    IRPM.run(*M);
  }

  legacy::PassManager PM;
  if (TM->addPassesToEmitFile(PM, Out->os(), /*DwoOut=*/nullptr,
                              CodeGenFileType::AssemblyFile,
                              /*DisableVerify=*/false)) {
    WithColor::error(errs(), argv[0])
        << "target does not support assembly file emission\n";
    return 1;
  }

  PM.run(*M);
  Out->keep();
  return 0;
}
