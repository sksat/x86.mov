//===-- MovRegisterInfo.cpp -----------------------------------------------===//
#include "MovRegisterInfo.h"
#include "MCTargetDesc/MovMCTargetDesc.h"
#include "MovFrameLowering.h"  // generated TargetDesc.inc references MovFrameLowering*
#include "llvm/CodeGen/MachineFunction.h"
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

bool MovRegisterInfo::eliminateFrameIndex(MachineBasicBlock::iterator /*MI*/,
                                          int /*SPAdj*/,
                                          unsigned /*FIOperandNum*/,
                                          RegScavenger * /*RS*/) const {
  // Stage 0 has no `alloca` and no stack arguments, so there are no frame
  // indices to eliminate. Fail loudly if one shows up unexpectedly — that
  // tells us a stage boundary slipped.
  llvm_unreachable("eliminateFrameIndex: no frame slots before stage 4");
}

Register MovRegisterInfo::getFrameRegister(const MachineFunction & /*MF*/) const {
  return Mov::EBP;
}
