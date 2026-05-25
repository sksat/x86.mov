//===-- MovFrameLowering.cpp ----------------------------------------------===//
#include "MovFrameLowering.h"
#include "MCTargetDesc/MovMCTargetDesc.h"
#include "MovInstrInfo.h"
#include "MovSubtarget.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/Support/ErrorHandling.h"

using namespace llvm;

void MovFrameLowering::emitPrologue(MachineFunction &MF,
                                    MachineBasicBlock &MBB) const {
  const auto &STI = MF.getSubtarget<MovSubtarget>();
  const TargetInstrInfo &TII = *STI.getInstrInfo();
  MachineFrameInfo &MFI = MF.getFrameInfo();

  // We don't model variable-sized allocations (alloca with non-constant
  // size, i.e. VLAs) at stage 4. Reject loudly rather than emit code that
  // tracks ESP-after-alloca without restoring it.
  if (MFI.hasVarSizedObjects())
    report_fatal_error(
        "Mov: variable-sized stack objects (VLAs / dynamic alloca) not "
        "yet supported. Stage 4 covers static alloca only.");

  MachineBasicBlock::iterator MBBI = MBB.begin();
  DebugLoc DL = MBBI != MBB.end() ? MBBI->getDebugLoc() : DebugLoc();

  //   push ebp
  BuildMI(MBB, MBBI, DL, TII.get(Mov::PUSH32r))
      .addReg(Mov::EBP, RegState::Kill);

  //   mov  ebp, esp
  BuildMI(MBB, MBBI, DL, TII.get(Mov::MOV32rr), Mov::EBP).addReg(Mov::ESP);

  //   sub  esp, <local_size>   ; skip when empty
  uint64_t StackSize = MFI.getStackSize();
  if (StackSize > 0) {
    BuildMI(MBB, MBBI, DL, TII.get(Mov::SUB32ri), Mov::ESP)
        .addReg(Mov::ESP)
        .addImm(StackSize);
  }
}

void MovFrameLowering::emitEpilogue(MachineFunction &MF,
                                    MachineBasicBlock &MBB) const {
  const auto &STI = MF.getSubtarget<MovSubtarget>();
  const TargetInstrInfo &TII = *STI.getInstrInfo();

  // Insert before the terminator (which is the RET pseudo).
  MachineBasicBlock::iterator MBBI = MBB.getFirstTerminator();
  DebugLoc DL = MBBI != MBB.end() ? MBBI->getDebugLoc() : DebugLoc();

  //   mov  esp, ebp     ; reverses both `sub esp, N` and any alloca-shrink
  BuildMI(MBB, MBBI, DL, TII.get(Mov::MOV32rr), Mov::ESP).addReg(Mov::EBP);

  //   pop  ebp
  BuildMI(MBB, MBBI, DL, TII.get(Mov::POP32r), Mov::EBP);
}

MachineBasicBlock::iterator
MovFrameLowering::eliminateCallFramePseudoInstr(
    MachineFunction &MF, MachineBasicBlock &MBB,
    MachineBasicBlock::iterator MI) const {
  const auto &STI = MF.getSubtarget<MovSubtarget>();
  const TargetInstrInfo &TII = *STI.getInstrInfo();

  // Operand 0 of ADJCALLSTACKDOWN/UP is the byte count for that side of the
  // call frame. cdecl is caller-cleaned, so the same byte count goes both
  // ways; operand 1 (the callee-pop amount) is always 0 for us.
  const uint64_t Amount = MI->getOperand(0).getImm();
  const DebugLoc DL = MI->getDebugLoc();
  const unsigned Opc = MI->getOpcode();

  if (Amount > 0) {
    //  DOWN -> reserve   args:  sub esp, Amount
    //  UP   -> release   args:  add esp, Amount
    const unsigned RealOp =
        (Opc == Mov::ADJCALLSTACKDOWN) ? Mov::SUB32ri : Mov::ADD32ri;
    BuildMI(MBB, MI, DL, TII.get(RealOp), Mov::ESP)
        .addReg(Mov::ESP)
        .addImm(Amount);
  }
  return MBB.erase(MI);
}
