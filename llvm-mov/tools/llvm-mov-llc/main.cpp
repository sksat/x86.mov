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
