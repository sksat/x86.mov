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
};
} // namespace llvm
