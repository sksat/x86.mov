//===-- MovTargetMachine.cpp ----------------------------------------------===//
#include "MovTargetMachine.h"
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

  bool addInstSelector() override {
    addPass(createMovISelDag(getMovTargetMachine(), getOptLevel()));
    return false;
  }
};
} // namespace

TargetPassConfig *MovTargetMachine::createPassConfig(PassManagerBase &PM) {
  return new MovPassConfig(*this, PM);
}

extern "C" void LLVMInitializeMovTarget() {
  RegisterTargetMachine<MovTargetMachine> X(getTheMovTarget());
}
