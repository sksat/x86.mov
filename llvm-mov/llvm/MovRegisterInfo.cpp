//===-- MovRegisterInfo.cpp -----------------------------------------------===//
#include "MovRegisterInfo.h"
#include "MCTargetDesc/MovMCTargetDesc.h"
#include "MovFrameLowering.h"  // generated TargetDesc.inc references MovFrameLowering*
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineInstr.h"
#include "llvm/CodeGen/MachineOperand.h"
#include "llvm/CodeGen/RegisterScavenging.h"
#include "llvm/CodeGen/TargetFrameLowering.h"
#include "llvm/Support/ErrorHandling.h"

#define GET_REGINFO_TARGET_DESC
#include "MovGenRegisterInfo.inc"

using namespace llvm;

// CSR_Mov is declared in MovCallingConv.td; the table is emitted into
// MovGenRegisterInfo.inc by TableGen.
extern const MCPhysReg CSR_Mov_SaveList[];

MovRegisterInfo::MovRegisterInfo()
    : MovGenRegisterInfo(/*RA=*/0) {}

const MCPhysReg *
MovRegisterInfo::getCalleeSavedRegs(const MachineFunction * /*MF*/) const {
  return CSR_Mov_SaveList;
}

BitVector MovRegisterInfo::getReservedRegs(const MachineFunction & /*MF*/) const {
  BitVector Reserved(getNumRegs());
  Reserved.set(Mov::ESP);
  // EBP is reserved only when we actually need a frame pointer. Stage 0–4
  // don't, but flipping this on later is a single line.
  return Reserved;
}

bool MovRegisterInfo::eliminateFrameIndex(MachineBasicBlock::iterator II,
                                          int SPAdj, unsigned FIOperandNum,
                                          RegScavenger * /*RS*/) const {
  MachineInstr &MI = *II;
  const MachineFunction &MF = *MI.getParent()->getParent();
  const MachineFrameInfo &MFI = MF.getFrameInfo();

  // Stage 2 has no prologue/epilogue and no local frame growth, so the
  // stack pointer is stable across the function. SPAdj is reserved for
  // call-frame-pseudo bookkeeping that we don't have yet — assert that it
  // stays zero so a stage-6 regression (lost stack adjustment around
  // calls) is loud.
  assert(SPAdj == 0 && "Mov: SPAdj!=0 unexpected before stage 6");

  const int FrameIndex = MI.getOperand(FIOperandNum).getIndex();
  // Fixed objects from LowerFormalArguments carry the absolute SP-relative
  // offset (4 + LocMemOffset). With no prologue running, that offset *is*
  // the runtime [ESP + n].
  const int64_t Offset = MFI.getObjectOffset(FrameIndex);

  MI.getOperand(FIOperandNum).ChangeToRegister(Mov::ESP, /*isDef=*/false);
  const int64_t OldDisp = MI.getOperand(FIOperandNum + 1).getImm();
  MI.getOperand(FIOperandNum + 1).setImm(OldDisp + Offset);
  return false;
}

Register MovRegisterInfo::getFrameRegister(const MachineFunction & /*MF*/) const {
  return Mov::EBP;
}
