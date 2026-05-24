//===-- MovTargetMachine.h --------------------------------------*- C++ -*-===//
#pragma once

#include "MovSubtarget.h"
#include "llvm/CodeGen/CodeGenTargetMachineImpl.h"
#include "llvm/Target/TargetMachine.h"

namespace llvm {
class MovTargetMachine : public CodeGenTargetMachineImpl {
public:
  MovTargetMachine(const Target &T, const Triple &TT, StringRef CPU,
                   StringRef FS, const TargetOptions &Options,
                   std::optional<Reloc::Model> RM,
                   std::optional<CodeModel::Model> CM,
                   CodeGenOptLevel OL, bool JIT);

  const MovSubtarget *getSubtargetImpl(const Function & /*F*/) const override {
    return &Subtarget;
  }

  TargetPassConfig *createPassConfig(PassManagerBase &PM) override;

  TargetLoweringObjectFile *getObjFileLowering() const override {
    return TLOF.get();
  }

private:
  std::unique_ptr<TargetLoweringObjectFile> TLOF;
  MovSubtarget Subtarget;
};

// Declared here so MovISelDAGToDAG.cpp and MovTargetMachine.cpp share a name.
FunctionPass *createMovISelDag(MovTargetMachine &TM, CodeGenOptLevel OptLevel);
} // namespace llvm
