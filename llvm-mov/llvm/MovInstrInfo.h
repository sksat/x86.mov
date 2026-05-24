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
};
} // namespace llvm
