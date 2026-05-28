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

// Stage 7g1 — does the module contain any IR-level f32 operation
// that triggers the SDAG soft-float libcall path? The injection is
// scoped to FAdd for now (`__addsf3`); follow-up stages add sub /
// mul / div / cmp / conversion helpers via the same shape.
// We check `getScalarType()` so that `<N x float>` ops the Scalarizer
// will later flatten still trigger the injection (same lesson as
// the stage-7f2 codex review on `udiv <N x i32>`).
static bool moduleNeedsAddSf3Helper(Module &M) {
  for (Function &F : M) {
    if (F.isDeclaration())
      continue;
    for (Instruction &I : instructions(F)) {
      if (I.getOpcode() == Instruction::FAdd &&
          I.getType()->getScalarType()->isFloatTy())
        return true;
    }
  }
  return false;
}

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
    return Existing;
  }
  Function *F = Function::Create(Ty, GlobalValue::LinkOnceODRLinkage, Name, &M);
  F->setCallingConv(CallingConv::C);
  return F;
}

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

  Value *Result = B.CreateBitCast(Step3, F32);
  B.CreateRet(Result);
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

  // Stage 7g1 — `__addsf3` body. Same shape as the DIV/REM helpers
  // above: scan the IR for the trigger op and inject when present.
  if (moduleNeedsAddSf3Helper(*M))
    injectAddSf3Helper(*M, Ctx);

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
    // Only i32 SELECTs are rewritten; i1 / pointer / aggregate
    // SELECTs (e.g. ones SROA leaves around for control flow
    // synthesis) keep going through the default Expand path.
    SmallVector<SelectInst *, 32> SelectList;
    for (Instruction &I : instructions(F))
      if (auto *S = dyn_cast<SelectInst>(&I))
        if (S->getType()->isIntegerTy(32))
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
