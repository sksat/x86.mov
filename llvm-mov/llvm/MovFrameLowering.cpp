//===-- MovFrameLowering.cpp ----------------------------------------------===//
#include "MovFrameLowering.h"
#include "MCTargetDesc/MovMCTargetDesc.h"
#include "MovInstrInfo.h"
#include "MovMachineFunctionInfo.h"
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

void MovFrameLowering::processFunctionBeforeFrameFinalized(
    MachineFunction &MF, RegScavenger * /*RS*/) const {
  // Walk every MachineInstr in the function to figure out which
  // scratch slots the post-PEI MovOnlyLegalize rewrite will need.
  // Two independent questions:
  //
  //   NeedsByteOpScratch     — does any byte-chain legalize-target
  //                            opcode appear (ADD32rr/ri at stage 7a,
  //                            AND/OR/XOR 32rr/ri at stage 7b1)? If
  //                            so reserve the 4 base slots (save_ecx,
  //                            save_edx, srcdst, idx) — they are
  //                            shared across all the byte-table
  //                            legalizers.
  //   NeedsRhsScratch        — does any rr-form specifically appear?
  //                            If so reserve a 5th slot (rhs_buf) for
  //                            the RHS register spill. ri-form's RHS
  //                            is a compile-time immediate that needs
  //                            no memory.
  //
  // ri-only functions reserve 16 bytes; rr-having functions reserve
  // 20 bytes; functions with no legalize target reserve none.
  bool NeedsByteOpScratch = false;
  bool NeedsRhsScratch = false;
  bool NeedsShiftSignScratch = false;
  bool NeedsShiftVarScratch = false;
  bool NeedsCmpMaskScratch = false;
  for (const MachineBasicBlock &MBB : MF) {
    for (const MachineInstr &MI : MBB) {
      switch (MI.getOpcode()) {
      case Mov::ADD32rr:
      case Mov::AND32rr:
      case Mov::OR32rr:
      case Mov::XOR32rr:
        NeedsByteOpScratch = true;
        NeedsRhsScratch = true;
        break;
      case Mov::ADD32ri:
      case Mov::AND32ri:
      case Mov::OR32ri:
      case Mov::XOR32ri:
      case Mov::SHL32ri:
      case Mov::SHR32ri:
        NeedsByteOpScratch = true;
        break;
      case Mov::SAR32ri:
        NeedsByteOpScratch = true;
        NeedsShiftSignScratch = true;
        break;
      case Mov::SHL32rCL:
      case Mov::SHR32rCL:
        NeedsByteOpScratch = true;
        NeedsShiftVarScratch = true;
        break;
      case Mov::SAR32rCL:
        NeedsByteOpScratch = true;
        NeedsShiftSignScratch = true;
        NeedsShiftVarScratch = true;
        break;
      case Mov::CMP32rr:
      case Mov::CMP32ri:
        // Stage 7c2 — CMP+Jcc(E/NE) legalize. Needs base 4 slots
        // (save_ecx/save_edx/srcdst/idx) plus rhs_buf (used to hold
        // the F-target label during the mask-based select; CMP32ri's
        // RHS is a compile-time immediate but we still need a
        // 4-byte slot for the F-label) plus a 1-byte mask buf
        // (mask at +0, inv_mask at +1).
        NeedsByteOpScratch = true;
        NeedsRhsScratch = true;
        NeedsCmpMaskScratch = true;
        break;
      default:
        break;
      }
    }
  }
  // Stage 7c1: any function with at least two basic blocks gets a
  // dispatcher `next_pc` slot reserved. The CFG rewrite in
  // MovOnlyLegalize uses it to store the next BB's code-pointer
  // before jumping through the dispatcher MBB. Single-BB functions
  // don't need the slot (no branches to rewrite).
  const bool NeedsDispatcher = MF.size() >= 2;

  if (!NeedsByteOpScratch && !NeedsDispatcher)
    return;

  auto *MovMFI = MF.getInfo<MovMachineFunctionInfo>();
  MachineFrameInfo &MFI = MF.getFrameInfo();
  const auto Make = [&]() {
    return MFI.CreateStackObject(/*Size=*/4, Align(4),
                                 /*isSpillSlot=*/false, /*Alloca=*/nullptr,
                                 /*ID=*/0);
  };

  if (NeedsDispatcher)
    MovMFI->setDispatcherNextPCBufFI(Make());

  if (!NeedsByteOpScratch)
    return;

  // Base 4 slots: save_ecx, save_edx, srcdst (source spill + result
  // buffer), idx (4-byte index pack slot). See stage 7a1 commit msg /
  // MovOnlyLegalize.cpp for layout rationale.
  MovMFI->setSavedParentSlotFI(Mov::ECX, Make());
  MovMFI->setSavedParentSlotFI(Mov::EDX, Make());
  MovMFI->setAddRewriteSrcDstFI(Make());
  MovMFI->setAddRewriteIdxFI(Make());

  // 5th slot — RHS spill — only when an rr-form byte-op is present.
  // Without this conditional, ri-only functions would grow by 4 bytes
  // of dead frame space.
  if (NeedsRhsScratch)
    MovMFI->setAddRewriteRhsFI(Make());

  // 6th slot — SAR sign byte buffer. Only allocated when at least one
  // SAR (ri or rCL) is in the function. The byte that ends up here is
  // the sign-extended byte (0x00 or 0xFF) used to substitute the
  // out-of-range source bytes that an arithmetic shift right pulls in
  // from "above" the 32-bit value.
  if (NeedsShiftSignScratch)
    MovMFI->setShiftSignBufFI(Make());

  // 7th/8th slots — variable-shift (rCL) buffers. amount_buf parks
  // the runtime shift count (CL) before any ECX clobber; shifted_buf
  // holds the alternative 32-bit value for each of the 5 power-of-2
  // stages.
  if (NeedsShiftVarScratch) {
    MovMFI->setShiftAmountBufFI(Make());
    MovMFI->setShiftShiftedBufFI(Make());
  }

  // Stage 7c2 slot — CMP+Jcc(E/NE) mask buffer. Holds the predicate
  // mask byte (0x00 / 0xFF) at +0 and its bitwise inverse at +1 so
  // the per-byte mask-select during the cmp+jcc rewrite has stable
  // access to both across the AND/OR table lookups (which clobber
  // ECX/DL/CL on every step).
  if (NeedsCmpMaskScratch)
    MovMFI->setCmpMaskBufFI(Make());
}
