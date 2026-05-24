//===-- MovFrameLowering.h --------------------------------------*- C++ -*-===//
#pragma once

#include "llvm/CodeGen/TargetFrameLowering.h"

namespace llvm {
class MovFrameLowering : public TargetFrameLowering {
public:
  MovFrameLowering()
      : TargetFrameLowering(StackGrowsDown, /*StackAlignment=*/Align(4),
                            /*LocalAreaOffset=*/0) {}

  // No prologue/epilogue at stage 0 — the only instructions in @main are
  // `mov eax, 0; ret`, so there's nothing to save and nothing to restore.
  void emitPrologue(MachineFunction &MF, MachineBasicBlock &MBB) const override {}
  void emitEpilogue(MachineFunction &MF, MachineBasicBlock &MBB) const override {}

  bool hasFPImpl(const MachineFunction & /*MF*/) const override { return false; }
};
} // namespace llvm
