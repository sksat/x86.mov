//===-- MovInstrInfo.cpp --------------------------------------------------===//
#include "MovInstrInfo.h"
#include "MCTargetDesc/MovMCTargetDesc.h"
#include "MovRegisterInfo.h"   // for Mov::GPR32RegClass declaration
#include "llvm/CodeGen/MachineBasicBlock.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/Support/ErrorHandling.h"

#define GET_INSTRINFO_CTOR_DTOR
#include "MovGenInstrInfo.inc"

using namespace llvm;

MovInstrInfo::MovInstrInfo(const TargetSubtargetInfo &STI,
                           const TargetRegisterInfo &TRI)
    : MovGenInstrInfo(STI, TRI,
                      /*CFSetupOpcode=*/~0u,
                      /*CFDestroyOpcode=*/~0u,
                      /*CatchRetOpcode=*/~0u,
                      /*ReturnOpcode=*/Mov::RET) {}

void MovInstrInfo::copyPhysReg(MachineBasicBlock &MBB,
                               MachineBasicBlock::iterator MI,
                               const DebugLoc &DL, Register DestReg,
                               Register SrcReg, bool KillSrc,
                               bool /*RenamableDest*/,
                               bool /*RenamableSrc*/) const {
  if (Mov::GPR32RegClass.contains(DestReg.asMCReg(), SrcReg.asMCReg())) {
    BuildMI(MBB, MI, DL, get(Mov::MOV32rr), DestReg)
        .addReg(SrcReg, getKillRegState(KillSrc));
    return;
  }
  llvm_unreachable("Mov::copyPhysReg: only GPR32->GPR32 supported");
}

void MovInstrInfo::storeRegToStackSlot(MachineBasicBlock &MBB,
                                       MachineBasicBlock::iterator MI,
                                       Register SrcReg, bool isKill,
                                       int FrameIndex,
                                       const TargetRegisterClass *RC,
                                       Register /*VReg*/,
                                       MachineInstr::MIFlag Flags) const {
  if (!Mov::GPR32RegClass.hasSubClassEq(RC))
    llvm_unreachable("Mov::storeRegToStackSlot: only GPR32 supported");

  DebugLoc DL = MBB.findDebugLoc(MI);
  // mov dword ptr [FI + 0], SrcReg
  // PEI rewrites the FrameIndex operand pair to (EBP, offset) via
  // MovRegisterInfo::eliminateFrameIndex once the local frame is laid out.
  BuildMI(MBB, MI, DL, get(Mov::MOV32mr))
      .setMIFlag(Flags)
      .addFrameIndex(FrameIndex)
      .addImm(0)
      .addReg(SrcReg, getKillRegState(isKill));
}

void MovInstrInfo::loadRegFromStackSlot(MachineBasicBlock &MBB,
                                        MachineBasicBlock::iterator MI,
                                        Register DestReg, int FrameIndex,
                                        const TargetRegisterClass *RC,
                                        Register /*VReg*/, unsigned /*SubReg*/,
                                        MachineInstr::MIFlag Flags) const {
  if (!Mov::GPR32RegClass.hasSubClassEq(RC))
    llvm_unreachable("Mov::loadRegFromStackSlot: only GPR32 supported");

  DebugLoc DL = MBB.findDebugLoc(MI);
  // mov DestReg, dword ptr [FI + 0]
  BuildMI(MBB, MI, DL, get(Mov::MOV32rm), DestReg)
      .setMIFlag(Flags)
      .addFrameIndex(FrameIndex)
      .addImm(0);
}
