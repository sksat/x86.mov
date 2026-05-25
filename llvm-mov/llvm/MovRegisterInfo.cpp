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
  // Stage 4 reserves only the stack pointer and the frame pointer.
  // EBP is owned by MovFrameLowering as the frame pointer (push ebp/
  // mov ebp,esp in the prologue), and is therefore never available to
  // register allocation. EBX/ESI/EDI move back into the allocation pool
  // here; the cdecl preservation contract for them is handled by
  // PEI through CSR_Mov + storeRegToStackSlot.
  Reserved.set(Mov::ESP);
  Reserved.set(Mov::EBP);
  return Reserved;
}

bool MovRegisterInfo::eliminateFrameIndex(MachineBasicBlock::iterator II,
                                          int SPAdj, unsigned FIOperandNum,
                                          RegScavenger * /*RS*/) const {
  MachineInstr &MI = *II;
  const MachineFunction &MF = *MI.getParent()->getParent();
  const MachineFrameInfo &MFI = MF.getFrameInfo();

  // SPAdj is reserved for call-frame-pseudo bookkeeping that we don't have
  // yet — assert that it stays zero so a stage-6 regression (lost stack
  // adjustment around calls) is loud.
  assert(SPAdj == 0 && "Mov: SPAdj!=0 unexpected before stage 6");

  const int FrameIndex = MI.getOperand(FIOperandNum).getIndex();

  // Stage 4: every frame access is EBP-relative. The frame layout after
  // emitPrologue is
  //
  //                       [ebp + 8 + N]   arg N        (fixed object)
  //                       [ebp + 8]       arg 0        (fixed object)
  //                       [ebp + 4]       return address
  //   EBP/ESP-on-entry → [ebp + 0]       saved EBP
  //                       [ebp - 4]       first local / spill
  //                       ...
  //
  // MFI.getObjectOffset returns:
  //   - for fixed objects (args): the SPOffset we passed at construction,
  //     which is (4 + LocMemOffset) — the offset from ESP-on-entry. ESP-
  //     on-entry sits one slot *above* saved EBP, so adding 4 turns it
  //     into an EBP-relative offset.
  //   - for local/spill objects: a negative offset from the local-area
  //     base, which for us *is* EBP (LocalAreaOffset = 0).
  int64_t Offset = MFI.getObjectOffset(FrameIndex);
  if (MFI.isFixedObjectIndex(FrameIndex))
    Offset += 4; // skip past the saved-EBP slot

  MI.getOperand(FIOperandNum).ChangeToRegister(Mov::EBP, /*isDef=*/false);
  const int64_t OldDisp = MI.getOperand(FIOperandNum + 1).getImm();
  MI.getOperand(FIOperandNum + 1).setImm(OldDisp + Offset);
  return false;
}

Register MovRegisterInfo::getFrameRegister(const MachineFunction & /*MF*/) const {
  return Mov::EBP;
}
