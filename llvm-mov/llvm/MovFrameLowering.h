//===-- MovFrameLowering.h --------------------------------------*- C++ -*-===//
#pragma once

#include "llvm/CodeGen/TargetFrameLowering.h"

namespace llvm {
class MovFrameLowering : public TargetFrameLowering {
public:
  MovFrameLowering()
      : TargetFrameLowering(StackGrowsDown, /*StackAlignment=*/Align(4),
                            /*LocalAreaOffset=*/0) {}

  // Stage 4a: real prologue/epilogue around an EBP-based frame.
  //   push ebp
  //   mov  ebp, esp
  //   sub  esp, <local_size>      ; only when MFI.getStackSize() > 0
  //   ...
  //   mov  esp, ebp                ; reverses any sub esp + tolerates alloca
  //   pop  ebp
  //   ret                          ; emitted separately, via the RET pseudo
  void emitPrologue(MachineFunction &MF, MachineBasicBlock &MBB) const override;
  void emitEpilogue(MachineFunction &MF, MachineBasicBlock &MBB) const override;

  // We now always have a frame pointer (EBP). Stage-4 simplicity wins over
  // the "leaf functions don't need FP" optimisation — stage 6 and beyond
  // benefit from the consistency.
  bool hasFPImpl(const MachineFunction & /*MF*/) const override { return true; }
};
} // namespace llvm
