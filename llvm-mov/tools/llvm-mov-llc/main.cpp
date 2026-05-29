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
