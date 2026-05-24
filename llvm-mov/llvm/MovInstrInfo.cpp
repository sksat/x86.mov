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
