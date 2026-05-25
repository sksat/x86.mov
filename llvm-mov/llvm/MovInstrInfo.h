//===-- MovInstrInfo.h ------------------------------------------*- C++ -*-===//
#pragma once

#include "llvm/CodeGen/TargetInstrInfo.h"

#define GET_INSTRINFO_HEADER
#include "MovGenInstrInfo.inc"

namespace llvm {
class MovSubtarget;

class MovInstrInfo : public MovGenInstrInfo {
public:
  MovInstrInfo(const TargetSubtargetInfo &STI, const TargetRegisterInfo &TRI);

  void copyPhysReg(MachineBasicBlock &MBB, MachineBasicBlock::iterator MI,
                   const DebugLoc &DL, Register DestReg, Register SrcReg,
                   bool KillSrc, bool RenamableDest = false,
                   bool RenamableSrc = false) const override;

  // Register spill hooks. Required so that Greedy RA can intercept its
  // *own* spill decisions with a readable diagnostic instead of crashing
  // somewhere deep in the allocator when it tries to call the default
  // (llvm_unreachable) implementations. Real spill machinery (MOV32mr
  // + ESP-adjusting prologue/epilogue) lands at stage 4.
  void storeRegToStackSlot(
      MachineBasicBlock &MBB, MachineBasicBlock::iterator MI, Register SrcReg,
      bool isKill, int FrameIndex, const TargetRegisterClass *RC, Register VReg,
      MachineInstr::MIFlag Flags = MachineInstr::NoFlags) const override;

  void loadRegFromStackSlot(
      MachineBasicBlock &MBB, MachineBasicBlock::iterator MI, Register DestReg,
      int FrameIndex, const TargetRegisterClass *RC, Register VReg,
      unsigned SubReg = 0,
      MachineInstr::MIFlag Flags = MachineInstr::NoFlags) const override;

  // Branch manipulation hooks used by BranchFolder, MachineBlockPlacement,
  // etc. analyzeBranch + removeBranch + insertBranch + reverseBranchCondition
  // form a quartet that the codegen-side passes treat as a unit; returning
  // "can't analyze" from analyzeBranch is not enough because some passes
  // (notably BranchFolder's tail-merge path) still call removeBranch on
  // blocks they want to mutate, and the default removeBranch / insertBranch
  // are `llvm_unreachable`. So we implement all four together.
  //
  // Conditional shape we emit at stage 5b is exactly
  //     (optional Jcc target1) (optional JMP target2)
  // where Jcc takes its EFLAGS-defining CMP via glue. Cond[0] carries the
  // Jcc opcode as an i32 immediate so insertBranch / reverseBranchCondition
  // can re-emit the matching mnemonic without going back to LLVM IR.
  bool analyzeBranch(MachineBasicBlock &MBB, MachineBasicBlock *&TBB,
                     MachineBasicBlock *&FBB,
                     SmallVectorImpl<MachineOperand> &Cond,
                     bool AllowModify = false) const override;

  unsigned removeBranch(MachineBasicBlock &MBB,
                        int *BytesRemoved = nullptr) const override;

  unsigned insertBranch(MachineBasicBlock &MBB, MachineBasicBlock *TBB,
                        MachineBasicBlock *FBB, ArrayRef<MachineOperand> Cond,
                        const DebugLoc &DL,
                        int *BytesAdded = nullptr) const override;

  bool reverseBranchCondition(
      SmallVectorImpl<MachineOperand> &Cond) const override;
};
} // namespace llvm
