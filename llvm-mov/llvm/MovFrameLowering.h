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

  // Stage 6a: PEI inserts ADJCALLSTACKDOWN/ADJCALLSTACKUP around every
  // call so it can track the temporary ESP movement that the caller's
  // argument pushes make. We rewrite each pseudo into the matching
  // `sub esp, N` / `add esp, N` here (or erase it entirely if N == 0).
  MachineBasicBlock::iterator
  eliminateCallFramePseudoInstr(MachineFunction &MF, MachineBasicBlock &MBB,
                                MachineBasicBlock::iterator MI) const override;
};
} // namespace llvm
