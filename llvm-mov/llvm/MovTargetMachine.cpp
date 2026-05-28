//===-- MovTargetMachine.cpp ----------------------------------------------===//
#include "MovTargetMachine.h"
#include "MovMachineFunctionInfo.h"
#include "TargetInfo/MovTargetInfo.h"
#include "llvm/CodeGen/Passes.h"
#include "llvm/CodeGen/TargetLoweringObjectFileImpl.h"
#include "llvm/CodeGen/TargetPassConfig.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/CodeGen.h"

using namespace llvm;

namespace {
// Stage 0: emit GAS Intel-syntax x86-32 text. Data layout matches what the
// stock 32-bit x86 backend uses on Linux so SelectionDAG legalization gives
// us the lane widths we expect.
std::string computeDataLayout() {
  return "e-m:e-p:32:32-i64:32-f64:32-f80:32-n8:16:32-S32";
}

Reloc::Model getEffectiveRelocModel(std::optional<Reloc::Model> RM) {
  return RM.value_or(Reloc::Static);
}
} // namespace

MovTargetMachine::MovTargetMachine(const Target &T, const Triple &TT,
                                   StringRef CPU, StringRef FS,
                                   const TargetOptions &Options,
                                   std::optional<Reloc::Model> RM,
                                   std::optional<CodeModel::Model> CM,
                                   CodeGenOptLevel OL, bool JIT)
    : CodeGenTargetMachineImpl(T, computeDataLayout(), TT, CPU, FS, Options,
                               getEffectiveRelocModel(RM),
                               CM.value_or(CodeModel::Small), OL),
      TLOF(std::make_unique<TargetLoweringObjectFileELF>()),
      Subtarget(TT, CPU, FS, *this) {
  initAsmInfo();
}

namespace {
class MovPassConfig : public TargetPassConfig {
public:
  MovPassConfig(MovTargetMachine &TM, PassManagerBase &PM)
      : TargetPassConfig(TM, PM) {}

  MovTargetMachine &getMovTargetMachine() const {
    return getTM<MovTargetMachine>();
  }

  // Stage 6d3b — IR-level i8/i16 promotion (disabled).
  //
  // LLVM's TypePromotion was originally intended to fold i8/i16
  // clusters up to i32 so DAG-ISel never had to legalise narrow
  // SSA values. The 6d3b Custom (ext)load/truncstore lowering
  // ended up solving the same problem at SDAG time, so the pass
  // is no longer load-bearing — and on base64-class IR it
  // contributes nontrivial compile time. Left wired but disabled
  // for now; flip back on if a fixture starts producing IR the
  // SDAG path can't promote cleanly.
  void addIRPasses() override {
    // addPass(createTypePromotionLegacyPass());
    TargetPassConfig::addIRPasses();
  }

  bool addInstSelector() override {
    addPass(createMovISelDag(getMovTargetMachine(), getOptLevel()));
    return false;
  }

  // Stage 7+: MovOnlyLegalize runs as a pre-emit pass, after RegAlloc /
  // PEI / BranchFolder have settled the MIR into its final shape but
  // before AsmPrinter walks it. Per codex's stage-7 design pass this is
  // the only safe place — we need finalized physical registers and a
  // stable CFG for the rewriting to make sense.
  void addPreEmitPass() override {
    addPass(createMovOnlyLegalizePass());
  }
};
} // namespace

TargetPassConfig *MovTargetMachine::createPassConfig(PassManagerBase &PM) {
  return new MovPassConfig(*this, PM);
}

MachineFunctionInfo *MovTargetMachine::createMachineFunctionInfo(
    BumpPtrAllocator &Allocator, const Function &F,
    const TargetSubtargetInfo *STI) const {
  return MovMachineFunctionInfo::create<MovMachineFunctionInfo>(Allocator, F,
                                                                STI);
}

extern "C" void LLVMInitializeMovTarget() {
  RegisterTargetMachine<MovTargetMachine> X(getTheMovTarget());
}
