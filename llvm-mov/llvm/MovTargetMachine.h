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

  // Stage 7-prep-2c: per-function MovMachineFunctionInfo holding the
  // scratch-slot bookkeeping that MovFrameLowering reserves pre-PEI
  // and MovOnlyLegalize consumes post-PEI.
  MachineFunctionInfo *
  createMachineFunctionInfo(BumpPtrAllocator &Allocator, const Function &F,
                            const TargetSubtargetInfo *STI) const override;

private:
  std::unique_ptr<TargetLoweringObjectFile> TLOF;
  MovSubtarget Subtarget;
};

// Declared here so MovISelDAGToDAG.cpp and MovTargetMachine.cpp share a name.
FunctionPass *createMovISelDag(MovTargetMachine &TM, CodeGenOptLevel OptLevel);

// Stage 7+: MachineFunctionPass that rewrites mov-heavy MIR into
// mov-only sequences via lookup tables and (later) branchless dispatch.
// At stage 7a0 the pass is wired but does nothing; the entry point is
// stable so subsequent stages just grow the per-opcode body.
FunctionPass *createMovOnlyLegalizePass();
} // namespace llvm
