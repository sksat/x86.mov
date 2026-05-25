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

//===----------------------------------------------------------------------===//
// Branch manipulation — analyzeBranch / removeBranch / insertBranch /
// reverseBranchCondition. Cond[0] carries the Jcc opcode as an i32 immediate
// so insertBranch and reverseBranchCondition can round-trip without
// re-reasoning about the original ISD::CondCode.
//===----------------------------------------------------------------------===//

namespace {
// Flip the predicate of a Jcc opcode. EQ↔NE, signed L↔GE / G↔LE,
// unsigned B↔AE / A↔BE. Each pair is true ⇔ ¬other.
unsigned reverseJccOpcode(unsigned Opc) {
  switch (Opc) {
  case Mov::JE:  return Mov::JNE;
  case Mov::JNE: return Mov::JE;
  case Mov::JL:  return Mov::JGE;
  case Mov::JGE: return Mov::JL;
  case Mov::JG:  return Mov::JLE;
  case Mov::JLE: return Mov::JG;
  case Mov::JB:  return Mov::JAE;
  case Mov::JAE: return Mov::JB;
  case Mov::JA:  return Mov::JBE;
  case Mov::JBE: return Mov::JA;
  }
  llvm_unreachable("Mov: unknown Jcc opcode in reverseJccOpcode");
}

bool isJcc(unsigned Opc) {
  switch (Opc) {
  case Mov::JE:  case Mov::JNE:
  case Mov::JL:  case Mov::JGE:
  case Mov::JG:  case Mov::JLE:
  case Mov::JB:  case Mov::JAE:
  case Mov::JA:  case Mov::JBE:
    return true;
  default:
    return false;
  }
}
} // namespace

bool MovInstrInfo::analyzeBranch(MachineBasicBlock &MBB,
                                 MachineBasicBlock *&TBB,
                                 MachineBasicBlock *&FBB,
                                 SmallVectorImpl<MachineOperand> &Cond,
                                 bool /*AllowModify*/) const {
  TBB = nullptr;
  FBB = nullptr;
  Cond.clear();

  // Walk back from the end past debug instrs to the last "real" insn.
  MachineBasicBlock::iterator I = MBB.end();
  while (I != MBB.begin()) {
    --I;
    if (!I->isDebugInstr())
      break;
  }
  if (I == MBB.end() || !I->isTerminator())
    return false; // falls through to layout successor

  // Inspect the trailing terminators in reverse: at most one unconditional
  // JMP, optionally preceded by one conditional Jcc. Anything else (e.g. RET
  // alone, or a chain we don't recognise) bails to "can't analyze".
  MachineInstr *Last = &*I;
  unsigned LastOpc = Last->getOpcode();

  if (LastOpc == Mov::JMP) {
    TBB = Last->getOperand(0).getMBB();
    if (I == MBB.begin())
      return false; // just an unconditional jump
    --I;
    while (I != MBB.begin() && I->isDebugInstr())
      --I;
    if (I->isDebugInstr() || !I->isTerminator())
      return false;
    if (isJcc(I->getOpcode())) {
      // Jcc <target1> ; JMP <target2>
      FBB = TBB;
      TBB = I->getOperand(0).getMBB();
      Cond.push_back(MachineOperand::CreateImm(I->getOpcode()));
      return false;
    }
    return true; // unknown second-to-last terminator
  }

  if (isJcc(LastOpc)) {
    // Falls through on the false side.
    TBB = Last->getOperand(0).getMBB();
    Cond.push_back(MachineOperand::CreateImm(LastOpc));
    return false;
  }

  // Some other terminator (RET, etc.) — we can't help.
  return true;
}

unsigned MovInstrInfo::removeBranch(MachineBasicBlock &MBB,
                                    int *BytesRemoved) const {
  if (BytesRemoved)
    *BytesRemoved = 0;
  unsigned Count = 0;
  MachineBasicBlock::iterator I = MBB.end();
  while (I != MBB.begin()) {
    --I;
    if (I->isDebugInstr())
      continue;
    if (I->getOpcode() != Mov::JMP && !isJcc(I->getOpcode()))
      break;
    I = MBB.erase(I);
    ++Count;
    // erase returns the iterator after the removed element; we want to
    // re-position to the previous element for the next loop.
    if (I == MBB.begin())
      break;
  }
  return Count;
}

unsigned MovInstrInfo::insertBranch(MachineBasicBlock &MBB,
                                    MachineBasicBlock *TBB,
                                    MachineBasicBlock *FBB,
                                    ArrayRef<MachineOperand> Cond,
                                    const DebugLoc &DL,
                                    int *BytesAdded) const {
  if (BytesAdded)
    *BytesAdded = 0;
  // Mirror of removeBranch's shape.
  // Conditional shapes:
  //   - Cond empty, FBB null:   single JMP TBB
  //   - Cond non-empty, FBB null: single Jcc TBB        (fall through on false)
  //   - Cond non-empty, FBB set:  Jcc TBB ; JMP FBB
  // The opcode in Cond[0] (the Jcc) was stamped by analyzeBranch.
  if (Cond.empty()) {
    BuildMI(&MBB, DL, get(Mov::JMP)).addMBB(TBB);
    return 1;
  }
  unsigned JccOpc = Cond[0].getImm();
  BuildMI(&MBB, DL, get(JccOpc)).addMBB(TBB);
  if (!FBB)
    return 1;
  BuildMI(&MBB, DL, get(Mov::JMP)).addMBB(FBB);
  return 2;
}

bool MovInstrInfo::reverseBranchCondition(
    SmallVectorImpl<MachineOperand> &Cond) const {
  if (Cond.size() != 1)
    return true; // can't reverse
  Cond[0].setImm(reverseJccOpcode(Cond[0].getImm()));
  return false;
}
