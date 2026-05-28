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

  // Stage 6d3b — IR-level i8/i16 promotion.
  //
  // The DAG-ISel path cannot handle i8 SSA values: a bare
  // `load i8` + `zext i8 to i32` legalises into an unsupported
  // `extload (s8) anyext` SDNode, and chained i8 binops balloon
  // DAG-ISel into multi-minute compile times. LLVM's TypePromotion
  // pass clusters i8/i16 ops and their consumers, promotes the
  // cluster to a wider legal type (i32 here), and inserts trunc
  // at boundaries — so the post-pass IR stays in pure i32-land
  // and selects against the existing MOV32rm + AND32ri / SHR32ri
  // patterns.
  //
  // ARM / AArch64 hook this up via their own pass config; we run
  // it as the first thing in addIRPasses so the rest of the
  // pre-codegen chain (Scalarizer runs in the driver before us)
  // sees the already-promoted IR.
  void addIRPasses() override {
    addPass(createTypePromotionLegacyPass());
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
