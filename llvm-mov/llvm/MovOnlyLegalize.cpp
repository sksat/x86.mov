//===-- MovOnlyLegalize.cpp -------------------------------------*- C++ -*-===//
//
// MovOnlyLegalize — a MachineFunctionPass that rewrites every non-`mov`
// instruction the backend emitted at stages 0–6 into mov-only sequences.
// This is the whole project's namesake.
//
// Pipeline position: runs in addPreEmitPass — after RegAlloc, PEI, and
// BranchFolder, before AsmPrinter. All registers are physical, the
// frame is finalised (`sub esp, N` already burned into the prologue,
// every FrameIndex resolved to (EBP, disp)), and the CFG is stable.
// Stack slots the rewrite needs are reserved one stage earlier, in
// `MovFrameLowering::processFunctionBeforeFrameFinalized`; we only
// look them up here.
//
// Stage breakdown:
//   7a0  pass skeleton + addPreEmitPass wiring + gate harness — landed.
//   7a1  ADD32ri  — first real legalization (this stage). Each 32-bit
//                   add is decomposed into four 8-bit adds chained by
//                   carry; the per-byte add is a pair of table reads
//                   (__mov_add8_sum_table / __mov_add8_carry_table)
//                   indexed by (cin, a_byte, b_byte). ADD32rr is held
//                   back to a separate commit (needs an additional
//                   spill slot for the RHS register) and still falls
//                   through to no-op.
//   7b1  AND/OR/XOR  — same framework, different lookup table.
//   7b2  SHL/SHR/SAR — separate because shift carry/bit-extraction is a
//                      different table shape from add.
//   7c   CMP+Jcc+JMP — must be legalised as a unit; the control-flow
//                      substrate changes. Codex flagged segment-register
//                      self-modification (the famous movfuscator trick)
//                      as a *trap* if used here first: ELF section
//                      permissions + W^X + the late-MI CFG world
//                      collide. Initial 7c will use a branchless
//                      dispatcher instead.
//   7d   CALL+RET    — call/ret share the return-address machinery,
//                      so they're done together once 7c's substrate is
//                      in place. The function prologue's
//                      `push ebp / mov ebp, esp / sub esp, N` and the
//                      epilogue's `mov esp, ebp / pop ebp / ret` are
//                      legalised here too (they're the last remaining
//                      non-mov opcodes after 7a–7c).
//
// The `objdump`-based gate in test/MovOnly/run.sh checks "every line
// in .text uses an allowed mnemonic." At stage 7a1, ADD32ri is the
// only opcode this pass rewrites — push/pop/sub/ret are still emitted
// by FrameLowering and PEI. The gate supports a per-fixture `.expect`
// side file listing opcodes the fixture acknowledges as not-yet-
// legalised; stage 7d's job is to drive those files empty.
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/MovMCTargetDesc.h"
#include "MovInstrInfo.h"
#include "MovMachineFunctionInfo.h"
#include "MovSubtarget.h"
#include "MovTargetMachine.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SetVector.h"
#include "llvm/CodeGen/MachineBasicBlock.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstr.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/Passes.h"
#include "llvm/CodeGen/TargetInstrInfo.h"
#include "llvm/InitializePasses.h"
#include "llvm/Pass.h"
#include <array>
#include <cstdint>
#include <optional>
#include <utility>

using namespace llvm;

#define DEBUG_TYPE "mov-only-legalize"

namespace {
class MovOnlyLegalize : public MachineFunctionPass {
public:
  static char ID;
  MovOnlyLegalize() : MachineFunctionPass(ID) {}

  StringRef getPassName() const override {
    return "Mov-Only Legalization (stage 7+)";
  }

  bool runOnMachineFunction(MachineFunction &MF) override {
    bool Changed = false;
    const TargetInstrInfo &TII = *MF.getSubtarget<MovSubtarget>().getInstrInfo();

    // Stage 7c1: CFG-level rewrite for branches. Runs FIRST, before any
    // per-MI byte-chain rewrite below. Touches uncond JMP and fallthrough
    // edges; conditional Jcc stays as-is and is handled by 7c2 below.
    Changed |= legalizeCFG(MF, TII);

    // Stage 7c2: CMP+Jcc(E/NE) pair legalize. Runs AFTER legalizeCFG so it
    // sees the post-7c1 shape `cmp; mov [next_pc], F; jcc T; jmp
    // dispatcher` and can pick up the F-store left by 7c1. Replaces
    // the cmp + mov + jcc triplet with a mov-only sequence that writes
    // the predicate-selected target to next_pc.
    Changed |= legalizeCmpJccPairs(MF, TII);

    for (MachineBasicBlock &MBB : MF) {
      for (MachineInstr &MI : llvm::make_early_inc_range(MBB)) {
        switch (MI.getOpcode()) {
        case Mov::ADD32ri:
          Changed |= legalizeADD32ri(MI, MBB, TII);
          break;
        case Mov::ADD32rr:
          Changed |= legalizeADD32rr(MI, MBB, TII);
          break;
        case Mov::AND32ri:
          Changed |= legalizeBitwise32ri(MI, MBB, TII, "__mov_and8_table");
          break;
        case Mov::AND32rr:
          Changed |= legalizeBitwise32rr(MI, MBB, TII, "__mov_and8_table");
          break;
        case Mov::OR32ri:
          Changed |= legalizeBitwise32ri(MI, MBB, TII, "__mov_or8_table");
          break;
        case Mov::OR32rr:
          Changed |= legalizeBitwise32rr(MI, MBB, TII, "__mov_or8_table");
          break;
        case Mov::XOR32ri:
          Changed |= legalizeBitwise32ri(MI, MBB, TII, "__mov_xor8_table");
          break;
        case Mov::XOR32rr:
          Changed |= legalizeBitwise32rr(MI, MBB, TII, "__mov_xor8_table");
          break;
        case Mov::SHL32ri:
          Changed |= legalizeShift32ri(MI, MBB, TII, ShiftDir::SHL);
          break;
        case Mov::SHR32ri:
          Changed |= legalizeShift32ri(MI, MBB, TII, ShiftDir::SHR);
          break;
        case Mov::SAR32ri:
          Changed |= legalizeShift32ri(MI, MBB, TII, ShiftDir::SAR);
          break;
        case Mov::SHL32rCL:
          Changed |= legalizeShift32rCL(MI, MBB, TII, ShiftDir::SHL);
          break;
        case Mov::SHR32rCL:
          Changed |= legalizeShift32rCL(MI, MBB, TII, ShiftDir::SHR);
          break;
        case Mov::SAR32rCL:
          Changed |= legalizeShift32rCL(MI, MBB, TII, ShiftDir::SAR);
          break;
        // SUB rr/ri, CMP+Jcc, CALL32d + CALLSEQ, RET, and the
        // prologue/epilogue PUSH/POP/SUB/MOV sequence light up
        // across stages 7c → 7d.
        default:
          break;
        }
      }
    }
    return Changed;
  }

private:
  // Address triple for `[EBP + Disp]`. Built once per legalize site
  // and reused for every BuildMI in the byte chain. The RhsDisp slot
  // is only populated when the function has at least one rr-form
  // byte-op (ADD/AND/OR/XOR rr). The SignBufDisp is only populated
  // for functions containing at least one SAR32ri.
  struct EbpAddr {
    int64_t SaveEcxDisp;
    int64_t SaveEdxDisp;
    int64_t SrcDstDisp;
    int64_t IdxDisp;
    std::optional<int64_t> RhsDisp;
    std::optional<int64_t> SignBufDisp;
    std::optional<int64_t> AmountBufDisp;
    std::optional<int64_t> ShiftedBufDisp;
    std::optional<int64_t> CmpMaskBufDisp;
  };

  // Stage 7c1: resolve just the dispatcher's `next_pc` slot. CFG
  // legalize doesn't need any of the byte-chain scratch — it only
  // writes a 32-bit target address (via MOV32mi) and routes through
  // a JMP32m dispatcher MBB. Returns nullopt when the FrameLowering
  // scan didn't reserve the slot (single-BB function).
  static std::optional<int64_t>
  resolveDispatcherDisp(const MachineFunction &MF) {
    const auto *MovMFI = MF.getInfo<MovMachineFunctionInfo>();
    const int FI = MovMFI->getDispatcherNextPCBufFI();
    if (FI == -1)
      return std::nullopt;
    return MF.getFrameInfo().getObjectOffset(FI);
  }

  // Stage 7c2 — pre-pass that legalises `cmp; mov [next_pc], F; jcc(E/NE) T`
  // shapes (which is what 7c1 leaves behind after rewriting the trailing
  // uncond JMP / fallthrough). Each pair is replaced with a mov-only
  // sequence that writes the predicate-selected target to next_pc:
  //
  //   1. spill ECX, EDX, lhs, rhs (rhs is imm slice for CMP32ri)
  //   2. compute `lhs XOR rhs` byte-by-byte into srcdst (in place)
  //   3. OR-reduce srcdst[0..3] → DL = or_byte (0 iff lhs == rhs)
  //   4. mask = select_mask_table[or_byte]  ; 0xFF if !=, 0x00 if ==
  //      for JE, invert with XOR 0xFF; stash mask + inv_mask in cmp_mask_buf
  //   5. write T-label to srcdst (4-byte), F-label to rhs_buf (4-byte)
  //   6. per-byte select: next_pc[i] = (mask & T[i]) | (~mask & F[i])
  //   7. restore ECX, EDX
  //   8. erase CMP, the F-store MOV32mi, and Jcc; the trailing
  //      `jmp dispatcher` (also added by 7c1) is left intact.
  bool legalizeCmpJccPairs(MachineFunction &MF,
                           const TargetInstrInfo &TII) const {
    const std::optional<EbpAddr> Addr = resolveScratchAddrs(MF);
    if (!Addr || !Addr->RhsDisp || !Addr->CmpMaskBufDisp)
      return false;
    const std::optional<int64_t> NextPCDispOpt = resolveDispatcherDisp(MF);
    if (!NextPCDispOpt)
      return false;
    const int64_t NextPCDisp = *NextPCDispOpt;

    bool Changed = false;
    for (MachineBasicBlock &MBB : MF) {
      auto It = MBB.begin();
      while (It != MBB.end()) {
        const unsigned Op = It->getOpcode();
        if (Op != Mov::CMP32rr && Op != Mov::CMP32ri) {
          ++It;
          continue;
        }
        MachineInstr &CmpMI = *It;

        // Look forward (skipping debug instrs) for:
        //   - an optional MOV32mi to [EBP + NextPCDisp] (the F-store
        //     that 7c1 inserted before the Jcc)
        //   - immediately followed by JE or JNE
        // Anything else aborts the pattern match.
        MachineInstr *FStore = nullptr;
        MachineInstr *Jcc = nullptr;
        auto Probe = std::next(It);
        for (; Probe != MBB.end(); ++Probe) {
          if (Probe->isDebugInstr())
            continue;
          const unsigned POp = Probe->getOpcode();
          if (POp == Mov::MOV32mi && !FStore) {
            // Check it targets the next_pc slot.
            if (Probe->getNumOperands() >= 2 &&
                Probe->getOperand(0).isReg() &&
                Probe->getOperand(0).getReg() == Mov::EBP &&
                Probe->getOperand(1).isImm() &&
                Probe->getOperand(1).getImm() == NextPCDisp) {
              FStore = &*Probe;
              continue;
            }
            break;
          }
          if (POp == Mov::JE || POp == Mov::JNE) {
            Jcc = &*Probe;
            break;
          }
          // Anything else (other Jcc, RET, JMP, ...) breaks the pattern.
          break;
        }

        if (!Jcc) {
          ++It;
          continue;
        }

        // Extract operands.
        const Register LhsReg = CmpMI.getOperand(0).getReg();
        const bool IsImmRhs = (Op == Mov::CMP32ri);
        Register RhsReg;
        uint32_t Imm = 0;
        if (IsImmRhs)
          Imm = static_cast<uint32_t>(CmpMI.getOperand(1).getImm());
        else
          RhsReg = CmpMI.getOperand(1).getReg();

        MachineBasicBlock *TTarget = Jcc->getOperand(0).getMBB();
        MachineBasicBlock *FTarget = nullptr;
        if (FStore) {
          // MOV32mi operand layout: 0=base reg, 1=disp imm, 2=value
          // (here a MBB symbol).
          FTarget = FStore->getOperand(2).getMBB();
        }
        if (!FTarget) {
          ++It;
          continue;
        }
        const bool IsEQ = (Jcc->getOpcode() == Mov::JE);

        // Save the iterator past the Jcc — we'll resume scanning there
        // after the rewrite, since the dispatcher JMP that follows is
        // left intact.
        auto NextOuter = std::next(MachineBasicBlock::iterator(Jcc));
        auto Insert = MachineBasicBlock::iterator(&CmpMI);
        const DebugLoc DL = CmpMI.getDebugLoc();

        // === PROLOGUE: save ECX/EDX, spill lhs (and rhs for rr-form) ===
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
            .addReg(Mov::EBP).addImm(Addr->SaveEcxDisp).addReg(Mov::ECX);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
            .addReg(Mov::EBP).addImm(Addr->SaveEdxDisp).addReg(Mov::EDX);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
            .addReg(Mov::EBP).addImm(Addr->SrcDstDisp).addReg(LhsReg);
        if (!IsImmRhs) {
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
              .addReg(Mov::EBP).addImm(*Addr->RhsDisp).addReg(RhsReg);
        }

        // === PHASE 1: in-place XOR of srcdst[i] with rhs[i] ===
        // For each byte i, srcdst[i] = srcdst[i] XOR rhs[i]. After this
        // loop srcdst is the byte-wise XOR result (all-zero iff lhs == rhs).
        for (unsigned i = 0; i < 4; ++i) {
          const int64_t LhsByteDisp =
              Addr->SrcDstDisp + static_cast<int64_t>(i);

          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
              .addReg(Mov::EBP).addImm(LhsByteDisp);
          emitIdxZero(MBB, Insert, DL, TII, *Addr);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
              .addReg(Mov::EBP).addImm(Addr->IdxDisp + 1).addReg(Mov::DL);

          if (IsImmRhs) {
            const uint8_t RhsByte =
                static_cast<uint8_t>((Imm >> (8u * i)) & 0xFFu);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8ri), Mov::DL)
                .addImm(RhsByte);
          } else {
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
                .addReg(Mov::EBP).addImm(*Addr->RhsDisp + static_cast<int64_t>(i));
          }
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
              .addReg(Mov::EBP).addImm(Addr->IdxDisp).addReg(Mov::DL);

          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
              .addReg(Mov::EBP).addImm(Addr->IdxDisp);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
              .addExternalSymbol("__mov_xor8_table").addReg(Mov::ECX);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
              .addReg(Mov::EBP).addImm(LhsByteDisp).addReg(Mov::DL);
        }

        // === PHASE 2: OR-reduce srcdst[0..3] into DL ===
        // DL accumulates the OR: DL := srcdst[0]; then for i in 1..3,
        // DL := DL OR srcdst[i] via the OR8 table.
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
            .addReg(Mov::EBP).addImm(Addr->SrcDstDisp);
        for (unsigned i = 1; i < 4; ++i) {
          emitIdxZero(MBB, Insert, DL, TII, *Addr);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
              .addReg(Mov::EBP).addImm(Addr->IdxDisp + 1).addReg(Mov::DL);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
              .addReg(Mov::EBP).addImm(Addr->SrcDstDisp + static_cast<int64_t>(i));
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
              .addReg(Mov::EBP).addImm(Addr->IdxDisp).addReg(Mov::DL);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
              .addReg(Mov::EBP).addImm(Addr->IdxDisp);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
              .addExternalSymbol("__mov_or8_table").addReg(Mov::ECX);
        }
        // DL = or_byte (0 iff lhs == rhs).

        // === PHASE 3: compute predicate mask + invert for EQ + stash ===
        // mask := select_mask_table[or_byte]  → 0xFF if !=, 0x00 if ==.
        // For JE we invert with XOR 0xFF so mask matches "take T".
        emitUnaryByteLookup(MBB, Insert, DL, TII, *Addr, Mov::DL,
                            "__mov_select_mask_table", Mov::DL);
        if (IsEQ) {
          emitIdxZero(MBB, Insert, DL, TII, *Addr);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
              .addReg(Mov::EBP).addImm(Addr->IdxDisp + 1).addReg(Mov::DL);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8ri), Mov::DL).addImm(0xFF);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
              .addReg(Mov::EBP).addImm(Addr->IdxDisp).addReg(Mov::DL);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
              .addReg(Mov::EBP).addImm(Addr->IdxDisp);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
              .addExternalSymbol("__mov_xor8_table").addReg(Mov::ECX);
        }
        // Stash mask at cmp_mask_buf[0]
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
            .addReg(Mov::EBP).addImm(*Addr->CmpMaskBufDisp).addReg(Mov::DL);
        // Compute inv_mask = mask XOR 0xFF, stash at cmp_mask_buf[1]
        emitIdxZero(MBB, Insert, DL, TII, *Addr);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
            .addReg(Mov::EBP).addImm(Addr->IdxDisp + 1).addReg(Mov::DL);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8ri), Mov::DL).addImm(0xFF);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
            .addReg(Mov::EBP).addImm(Addr->IdxDisp).addReg(Mov::DL);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
            .addReg(Mov::EBP).addImm(Addr->IdxDisp);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
            .addExternalSymbol("__mov_xor8_table").addReg(Mov::ECX);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
            .addReg(Mov::EBP).addImm(*Addr->CmpMaskBufDisp + 1).addReg(Mov::DL);

        // === PHASE 4: write T-label to srcdst, F-label to rhs_buf ===
        // 4-byte stores of label addresses via MOV32mi.
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mi))
            .addReg(Mov::EBP).addImm(Addr->SrcDstDisp).addMBB(TTarget);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mi))
            .addReg(Mov::EBP).addImm(*Addr->RhsDisp).addMBB(FTarget);

        // === PHASE 5: per-byte mask-based select into next_pc ===
        // next_pc[i] = (mask & T[i]) | (~mask & F[i])
        for (unsigned i = 0; i < 4; ++i) {
          const int64_t NextPCByteDisp = NextPCDisp + static_cast<int64_t>(i);

          // (~mask & F[i]) → DL; stash to next_pc[i].
          emitIdxZero(MBB, Insert, DL, TII, *Addr);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
              .addReg(Mov::EBP).addImm(*Addr->CmpMaskBufDisp + 1);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
              .addReg(Mov::EBP).addImm(Addr->IdxDisp + 1).addReg(Mov::DL);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
              .addReg(Mov::EBP).addImm(*Addr->RhsDisp + static_cast<int64_t>(i));
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
              .addReg(Mov::EBP).addImm(Addr->IdxDisp).addReg(Mov::DL);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
              .addReg(Mov::EBP).addImm(Addr->IdxDisp);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
              .addExternalSymbol("__mov_and8_table").addReg(Mov::ECX);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
              .addReg(Mov::EBP).addImm(NextPCByteDisp).addReg(Mov::DL);

          // (mask & T[i]) → DL.
          emitIdxZero(MBB, Insert, DL, TII, *Addr);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
              .addReg(Mov::EBP).addImm(*Addr->CmpMaskBufDisp);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
              .addReg(Mov::EBP).addImm(Addr->IdxDisp + 1).addReg(Mov::DL);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
              .addReg(Mov::EBP).addImm(Addr->SrcDstDisp + static_cast<int64_t>(i));
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
              .addReg(Mov::EBP).addImm(Addr->IdxDisp).addReg(Mov::DL);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
              .addReg(Mov::EBP).addImm(Addr->IdxDisp);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
              .addExternalSymbol("__mov_and8_table").addReg(Mov::ECX);

          // OR the stashed (~mask & F[i]) at next_pc[i] with DL (mask & T[i]).
          emitOrByteAndStore(MBB, Insert, DL, TII, *Addr, NextPCDisp, i);
        }

        // === EPILOGUE: restore ECX, EDX ===
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
            .addReg(Mov::EBP).addImm(Addr->SaveEcxDisp);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::EDX)
            .addReg(Mov::EBP).addImm(Addr->SaveEdxDisp);

        // Erase the original CMP, the FStore MOV32mi (if present), and
        // the Jcc. The trailing `jmp dispatcher` (also added by 7c1)
        // stays — control flow now reaches it after our mov-only chain
        // has already populated next_pc.
        CmpMI.eraseFromParent();
        if (FStore)
          FStore->eraseFromParent();
        Jcc->eraseFromParent();

        // CFG fixup: the Jcc used to give MBB a direct edge to TTarget.
        // After the rewrite, MBB falls through to the trailing `jmp
        // dispatcher` and reaches TTarget through the dispatcher. So
        // (1) remove the stale MBB → TTarget edge, and (2) ensure the
        // dispatcher MBB has TTarget in its successor list. Without
        // both, `-verify-machineinstrs` complains "MBB has unexpected
        // successors" on functions like `is_42`.
        if (MBB.isSuccessor(TTarget))
          MBB.removeSuccessor(TTarget);
        // Find the dispatcher MBB (the only one containing JMP32m, set
        // up by legalizeCFG above) and route TTarget through it.
        MachineBasicBlock *Dispatcher = nullptr;
        for (MachineBasicBlock &D : MF) {
          for (const MachineInstr &DMI : D) {
            if (DMI.getOpcode() == Mov::JMP32m) {
              Dispatcher = &D;
              break;
            }
          }
          if (Dispatcher)
            break;
        }
        if (Dispatcher && !Dispatcher->isSuccessor(TTarget))
          Dispatcher->addSuccessor(TTarget);

        // Resume scanning past the Jcc we just erased.
        It = NextOuter;
        Changed = true;
      }
    }
    return Changed;
  }

  // True for our 10 conditional-branch opcodes. Mirrors MovInstrInfo.cpp's
  // analyzeBranch helper — duplicated here so this pass doesn't have to
  // depend on internals of MovInstrInfo.
  static bool isJcc(unsigned Opc) {
    switch (Opc) {
    case Mov::JE:
    case Mov::JNE:
    case Mov::JL:
    case Mov::JG:
    case Mov::JLE:
    case Mov::JGE:
    case Mov::JB:
    case Mov::JA:
    case Mov::JBE:
    case Mov::JAE:
      return true;
    default:
      return false;
    }
  }

  // Stage 7c1 — CFG-level legalization. Replaces unconditional JMPs and
  // implicit fallthrough edges with a uniform "store target address +
  // jump through a dispatcher MBB" pattern, so the per-branch direct
  // jump is replaced by a single indirect jump in the dispatcher.
  //
  // For each non-dispatcher BB:
  //   - terminator is uncond JMP: insert `MOV32mi [next_pc], <target>`
  //     before the first terminator, erase the JMP, append `JMP dispatcher`.
  //   - terminator is Jcc + (fallthrough or no explicit JMP for false
  //     side): insert `MOV32mi [next_pc], <layout_succ>` before the Jcc,
  //     append `JMP dispatcher`. The Jcc continues to take the
  //     true-side direct branch; the false side now flows through the
  //     dispatcher to layout_succ.
  //   - terminator is RET (or anything else non-branching): leave alone.
  //   - no terminator (pure fallthrough): insert mov + JMP dispatcher
  //     at the end.
  //
  // The dispatcher MBB at the end of the function holds a single
  // `JMP32m [next_pc]` (indirect jump through the slot we just wrote).
  //
  // The MOV32mi is inserted BEFORE the first existing terminator to
  // preserve the MIR invariant that terminators are contiguous at the
  // end of an MBB. `mov` doesn't touch EFLAGS, so a preceding Jcc that
  // reads EFLAGS from a `cmp` further up still sees the right flags.
  //
  // Returns true when at least one BB was rewritten.
  bool legalizeCFG(MachineFunction &MF, const TargetInstrInfo &TII) const {
    if (MF.size() < 2)
      return false;
    const std::optional<int64_t> NextPCDispOpt = resolveDispatcherDisp(MF);
    if (!NextPCDispOpt)
      return false;
    const int64_t NextPCDisp = *NextPCDispOpt;

    // (1) Create dispatcher MBB at the end of the function.
    MachineBasicBlock *Dispatcher = MF.CreateMachineBasicBlock();
    MF.push_back(Dispatcher);
    const DebugLoc EmptyDL;
    BuildMI(Dispatcher, EmptyDL, TII.get(Mov::JMP32m))
        .addReg(Mov::EBP)
        .addImm(NextPCDisp);

    SetVector<MachineBasicBlock *> DispatcherTargets;

    // (2) Snapshot the BB list before iterating — push_back of the
    // dispatcher above already happened, so we walk MBB list and skip
    // the dispatcher itself.
    SmallVector<MachineBasicBlock *, 8> BBList;
    for (MachineBasicBlock &MBB : MF)
      if (&MBB != Dispatcher)
        BBList.push_back(&MBB);

    bool Changed = false;
    for (MachineBasicBlock *MBB : BBList) {
      auto TermIt = MBB->getFirstTerminator();

      // Find the last terminator (if any) and classify the BB's exit.
      // Jcc instances are ignored on the scan — they stay where they
      // are; only RET (skip the BB entirely) and uncond JMP (rewrite
      // it) drive the decision.
      MachineInstr *UncondJmp = nullptr;
      bool HasReturn = false;
      for (auto It = TermIt; It != MBB->end(); ++It) {
        const unsigned Op = It->getOpcode();
        if (Op == Mov::JMP)
          UncondJmp = &*It;
        else if (Op == Mov::RET)
          HasReturn = true;
      }

      // RET-terminated BB: leave alone. Stage 7d handles the return
      // path; for 7c1, returning BBs don't go through the dispatcher.
      if (HasReturn)
        continue;

      // Determine the rewrite target.
      MachineBasicBlock *Target = nullptr;
      if (UncondJmp) {
        // Uncond JMP — its operand is the target MBB.
        Target = UncondJmp->getOperand(0).getMBB();
      } else {
        // No uncond JMP. Either Jcc-only-terminated (falls through to
        // layout_succ on the false side) or completely terminator-less
        // (also falls through). Both cases route the fallthrough to
        // layout_succ via dispatcher.
        const MachineFunction::iterator NextLayout =
            std::next(MachineFunction::iterator(MBB));
        if (NextLayout == MF.end())
          continue; // last MBB with no terminator — shouldn't happen
        if (&*NextLayout == Dispatcher)
          continue; // already at end (dispatcher is the next layout
                    // slot); no fallthrough action needed.
        Target = &*NextLayout;
      }

      if (!Target)
        continue;

      DispatcherTargets.insert(Target);

      // (3a) Insert `MOV32mi [next_pc], <target>` BEFORE the first
      // existing terminator (which may be a Jcc that reads EFLAGS;
      // mov doesn't touch EFLAGS so the Jcc still sees correct flags).
      const DebugLoc InsDL =
          (TermIt != MBB->end()) ? TermIt->getDebugLoc() : DebugLoc();
      BuildMI(*MBB, TermIt, InsDL, TII.get(Mov::MOV32mi))
          .addReg(Mov::EBP)
          .addImm(NextPCDisp)
          .addMBB(Target);

      // (3b) Erase the original uncond JMP if present (its CFG edge
      // gets recreated via the dispatcher).
      if (UncondJmp) {
        if (MBB->isSuccessor(Target))
          MBB->removeSuccessor(Target);
        UncondJmp->eraseFromParent();
      } else {
        // Fallthrough case: removeSuccessor for layout-succ Target.
        if (MBB->isSuccessor(Target))
          MBB->removeSuccessor(Target);
      }

      // (3c) Append `JMP dispatcher` at the end of MBB.
      BuildMI(MBB, EmptyDL, TII.get(Mov::JMP)).addMBB(Dispatcher);
      if (!MBB->isSuccessor(Dispatcher))
        MBB->addSuccessor(Dispatcher);

      Changed = true;
    }

    // (4) Add each target to the dispatcher's successor list so MIR
    // verifier / liveness understand reachability from the indirect
    // jump.
    for (MachineBasicBlock *T : DispatcherTargets) {
      if (!Dispatcher->isSuccessor(T))
        Dispatcher->addSuccessor(T);
    }

    if (!Changed) {
      // Nothing to dispatch — remove the dispatcher MBB to keep the CFG
      // tidy (no unreachable empty BB littering the asm).
      Dispatcher->eraseFromParent();
    }
    return Changed;
  }

  // Stage-7a1 placeholder — see the file-level comment for the design.
  //
  // All three prep-2 infrastructure pieces are now landed:
  //
  //   2a. `.rodata.__mov_add8_tables` emission for the byte-add lookup
  //       tables (MovAsmPrinter::emitEndOfAsmFile).
  //
  //   2b. `[<symbol> + <index_reg>]` addressing for byte loads via the
  //       MI-only operand `MovIdxMemOperand` + the codegen-only
  //       instruction `MOV8rm_idx` + printer routine
  //       `printIdxMemOperand`. No SelectAddr / ComplexPattern changes
  //       — legalize uses BuildMI directly with
  //       `.addExternalSymbol("__mov_add8_sum_table")` +
  //       `.addReg(IdxReg)`.
  //
  //   2c. Pre-PEI scratch-slot reservation in
  //       MovFrameLowering::processFunctionBeforeFrameFinalized, with
  //       the FI stored on MovMachineFunctionInfo and looked up here
  //       via `getSavedParentSlot(MF, Mov::ECX)`. Post-PEI
  //       MFI.CreateStackObject would be unsafe — by the time this
  //       pass runs, `sub esp, N` is already baked into the prologue
  //       and existing FIs are resolved.
  //
  // Stage 7a1 itself (the real ADD32 byte-chain rewrite) is the next
  // commit; until then legalizeADD32 keeps returning false so the
  // 39 execution fixtures + Rust example stay green and the
  // test/MovOnly gate stays empty.

  // Look up the EBP-relative displacement for the pre-PEI-reserved
  // scratch slots a stage-7a1 rewrite needs. Returns `std::nullopt` if
  // any base slot is missing (i.e. the FrameLowering scan didn't see
  // an ADD32 in this function and skipped reservation — legalize must
  // bail in that case). `RhsDisp` is populated only when the function
  // has at least one ADD32**rr**; ADD32ri-only callers leave it
  // nullopt and ignore it.
  //
  // All FIs are independent local objects, and MFI.getObjectOffset
  // returns each one's final layout offset directly (LocalAreaOffset
  // is 0 for our frame, so the offset *is* the EBP-relative disp).
  // Using these resolved displacements means BuildMI never touches a
  // FrameIndex operand here — the second eliminateFrameIndex pass that
  // would resolve one doesn't run.
  static std::optional<EbpAddr> resolveScratchAddrs(const MachineFunction &MF) {
    const auto *MovMFI = MF.getInfo<MovMachineFunctionInfo>();
    const int FI_Ecx = MovMFI->getSavedParentSlotFI(Mov::ECX);
    const int FI_Edx = MovMFI->getSavedParentSlotFI(Mov::EDX);
    const int FI_Sd = MovMFI->getAddRewriteSrcDstFI();
    const int FI_Ix = MovMFI->getAddRewriteIdxFI();
    if (FI_Ecx == -1 || FI_Edx == -1 || FI_Sd == -1 || FI_Ix == -1)
      return std::nullopt;
    const auto &MFI = MF.getFrameInfo();
    EbpAddr A{MFI.getObjectOffset(FI_Ecx),
              MFI.getObjectOffset(FI_Edx),
              MFI.getObjectOffset(FI_Sd),
              MFI.getObjectOffset(FI_Ix),
              std::nullopt,
              std::nullopt,
              std::nullopt,
              std::nullopt};
    const int FI_Rhs = MovMFI->getAddRewriteRhsFI();
    if (FI_Rhs != -1)
      A.RhsDisp = MFI.getObjectOffset(FI_Rhs);
    const int FI_Sign = MovMFI->getShiftSignBufFI();
    if (FI_Sign != -1)
      A.SignBufDisp = MFI.getObjectOffset(FI_Sign);
    const int FI_Amt = MovMFI->getShiftAmountBufFI();
    if (FI_Amt != -1)
      A.AmountBufDisp = MFI.getObjectOffset(FI_Amt);
    const int FI_Shifted = MovMFI->getShiftShiftedBufFI();
    if (FI_Shifted != -1)
      A.ShiftedBufDisp = MFI.getObjectOffset(FI_Shifted);
    const int FI_CmpMask = MovMFI->getCmpMaskBufFI();
    if (FI_CmpMask != -1)
      A.CmpMaskBufDisp = MFI.getObjectOffset(FI_CmpMask);
    return A;
  }

  // Per-byte source for the RHS operand `b_byte`. ADD32ri slices its
  // compile-time immediate (`ByteSource::Imm`); ADD32rr reads the
  // byte from a per-function memory spill (`ByteSource::MemDisp`,
  // `EBP + Disp + i`).
  struct ByteSource {
    enum class Kind { Imm, MemDisp } K;
    union {
      uint8_t Imm;
      int64_t MemDisp;
    };
    static ByteSource fromImm(uint8_t I) {
      ByteSource S;
      S.K = Kind::Imm;
      S.Imm = I;
      return S;
    }
    static ByteSource fromMem(int64_t D) {
      ByteSource S;
      S.K = Kind::MemDisp;
      S.MemDisp = D;
      return S;
    }
  };

  // Helper: zero the idx slot (4 bytes) in a SINGLE instruction via
  // `mov dword ptr [idx], 0`. After this returns, idx[0..3] = 0 and
  // **no GPR is clobbered** (previous versions used `mov ecx, 0;
  // mov [idx], ecx`, paying both an extra instruction and an ECX
  // clobber). The ECX-preservation is what lets ADD's carry chain
  // hold `carry_out` in CL across the zeroing without first copying
  // it through DL — see emitByteStageAdd's removed `mov dl, cl`.
  static void emitIdxZero(MachineBasicBlock &MBB,
                          MachineBasicBlock::iterator I, const DebugLoc &DL,
                          const TargetInstrInfo &TII, const EbpAddr &A) {
    BuildMI(MBB, I, DL, TII.get(Mov::MOV32mi))
        .addReg(Mov::EBP)
        .addImm(A.IdxDisp)
        .addImm(0);
  }

  // Helper: pack the a-byte (read from srcdst[ByteIdx]) and the
  // b-byte (from BSrc — either an immediate slice or a memory spill)
  // into idx[1] and idx[0] respectively. Trashes DL. Leaves idx[2..3]
  // as the caller set them — ADD writes carry into idx[2] BEFORE this
  // helper runs (so the a-byte read doesn't clobber the carry write).
  static void emitIdxPackAB(MachineBasicBlock &MBB,
                            MachineBasicBlock::iterator I, const DebugLoc &DL,
                            const TargetInstrInfo &TII, const EbpAddr &A,
                            unsigned ByteIdx, ByteSource BSrc) {
    const int64_t SrcByteDisp = A.SrcDstDisp + static_cast<int64_t>(ByteIdx);

    // mov dl, byte ptr [srcdst + i]   ; a_byte
    BuildMI(MBB, I, DL, TII.get(Mov::MOV8rm), Mov::DL)
        .addReg(Mov::EBP)
        .addImm(SrcByteDisp);
    // mov byte ptr [idx + 1], dl
    BuildMI(MBB, I, DL, TII.get(Mov::MOV8mr))
        .addReg(Mov::EBP)
        .addImm(A.IdxDisp + 1)
        .addReg(Mov::DL);

    // Load b_byte:
    if (BSrc.K == ByteSource::Kind::Imm) {
      // mov dl, IMM8                  ; compile-time immediate slice
      BuildMI(MBB, I, DL, TII.get(Mov::MOV8ri), Mov::DL).addImm(BSrc.Imm);
    } else {
      // mov dl, byte ptr [rhs_buf + i] ; rr-form RHS spill byte
      BuildMI(MBB, I, DL, TII.get(Mov::MOV8rm), Mov::DL)
          .addReg(Mov::EBP)
          .addImm(BSrc.MemDisp + static_cast<int64_t>(ByteIdx));
    }
    // mov byte ptr [idx + 0], dl
    BuildMI(MBB, I, DL, TII.get(Mov::MOV8mr))
        .addReg(Mov::EBP)
        .addImm(A.IdxDisp)
        .addReg(Mov::DL);
  }

  // Helper: load the packed index from idx into ECX, look up the
  // result byte from `[<TableSym> + ECX]` into DL, and write DL back
  // to srcdst[ByteIdx]. This is the common "read table, write byte"
  // sequence used by every byte-table legalizer.
  static void emitTableLookupAndStore(MachineBasicBlock &MBB,
                                      MachineBasicBlock::iterator I,
                                      const DebugLoc &DL,
                                      const TargetInstrInfo &TII,
                                      const EbpAddr &A, unsigned ByteIdx,
                                      const char *TableSym) {
    // mov ecx, dword ptr [idx]
    BuildMI(MBB, I, DL, TII.get(Mov::MOV32rm), Mov::ECX)
        .addReg(Mov::EBP)
        .addImm(A.IdxDisp);
    // mov dl, byte ptr [TableSym + ecx]
    BuildMI(MBB, I, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
        .addExternalSymbol(TableSym)
        .addReg(Mov::ECX);
    // mov byte ptr [srcdst + i], dl
    BuildMI(MBB, I, DL, TII.get(Mov::MOV8mr))
        .addReg(Mov::EBP)
        .addImm(A.SrcDstDisp + static_cast<int64_t>(ByteIdx))
        .addReg(Mov::DL);
  }

  // ADD per-byte stage: builds the index from (carry-in, a, b),
  // looks up the sum, writes it to srcdst[i], and loads the carry-out
  // into CL for the next stage. The boundary cases:
  //   - byte 0 has no carry-in — skip the `mov [idx+2], cl` write.
  //     emitIdxZero zeros idx[2] anyway.
  //   - byte 3 doesn't need carry-out — skip the trailing load.
  //
  // Since emitIdxZero no longer clobbers ECX, CL (carry from the
  // previous stage's `mov cl, [carry_table + ecx]`) survives across
  // the zeroing and can be written directly to idx[2] without an
  // intermediate `mov dl, cl` copy. Saves one mov per inner stage
  // (3 stages × 1 = 3 movs / ADD32 site, on top of the 4 movs the
  // emitIdxZero change buys directly).
  static void emitByteStageAdd(MachineBasicBlock &MBB,
                               MachineBasicBlock::iterator I,
                               const DebugLoc &DL,
                               const TargetInstrInfo &TII, const EbpAddr &A,
                               unsigned ByteIdx, ByteSource BSrc) {
    emitIdxZero(MBB, I, DL, TII, A);
    if (ByteIdx > 0) {
      // mov byte ptr [idx + 2], cl   ; carry-in byte (held in CL by
      // the previous stage's `mov cl, [carry_table + ecx]`)
      BuildMI(MBB, I, DL, TII.get(Mov::MOV8mr))
          .addReg(Mov::EBP)
          .addImm(A.IdxDisp + 2)
          .addReg(Mov::CL);
    }
    emitIdxPackAB(MBB, I, DL, TII, A, ByteIdx, BSrc);
    emitTableLookupAndStore(MBB, I, DL, TII, A, ByteIdx,
                            "__mov_add8_sum_table");
    if (ByteIdx < 3) {
      // mov cl, byte ptr [carry_table + ecx]  ; carry-out for next stage
      BuildMI(MBB, I, DL, TII.get(Mov::MOV8rm_idx), Mov::CL)
          .addExternalSymbol("__mov_add8_carry_table")
          .addReg(Mov::ECX);
    }
  }

  // Bitwise per-byte stage: AND/OR/XOR are per-bit, so each byte is
  // independent (no carry chain). Single table lookup, single store.
  // The (cin, a, b) index used by ADD becomes just (a, b) here —
  // idx[2..3] stay 0 from emitIdxZero, which is fine because the
  // bitwise tables are indexed by `a*256 + b` (only 16 bits of idx
  // matter, the rest is read as 0 by `mov ecx, [idx]`).
  static void emitByteStageBitwise(MachineBasicBlock &MBB,
                                   MachineBasicBlock::iterator I,
                                   const DebugLoc &DL,
                                   const TargetInstrInfo &TII,
                                   const EbpAddr &A, unsigned ByteIdx,
                                   ByteSource BSrc, const char *TableSym) {
    emitIdxZero(MBB, I, DL, TII, A);
    emitIdxPackAB(MBB, I, DL, TII, A, ByteIdx, BSrc);
    emitTableLookupAndStore(MBB, I, DL, TII, A, ByteIdx, TableSym);
  }

  // Stage 7a1 — lower a single `ADD32ri DST32, DST32, IMM32` into a
  // byte-chain mov-only sequence using the prep-2 infrastructure:
  //
  //   prologue: spill ECX, EDX, and the operand register (DST32) to
  //             their scratch slots.
  //   chain   : 4 byte stages, each looking up the per-byte sum and
  //             carry from the rodata tables and writing the sum
  //             back into the srcdst buffer in place; the carry-out
  //             of one stage rides in CL into the next.
  //   epilogue: restore ECX, EDX, then `mov DST32, [srcdst]` to load
  //             the final 32-bit result back into the destination
  //             register. The restore happens *before* the result
  //             load so that DST32 = ECX or DST32 = EDX still ends
  //             up with the result (the result load overwrites the
  //             just-restored save value).
  //
  // The original ADD32ri MI is erased at the end. Returns true so the
  // pass propagates "changed" to the pass manager.
  bool legalizeADD32ri(MachineInstr &MI, MachineBasicBlock &MBB,
                       const TargetInstrInfo &TII) const {
    const MachineFunction &MF = *MBB.getParent();
    const std::optional<EbpAddr> Addr = resolveScratchAddrs(MF);
    if (!Addr)
      return false; // pre-PEI scan didn't reserve slots; bail safely

    // ADD32ri operands: $dst (def, GPR32, tied to $src1), $src1 (use,
    // GPR32), $src2 (use, i32imm). 2-address tie makes op0.reg ==
    // op1.reg post-RA, so we work off operand 0 for the destination.
    assert(MI.getOperand(0).isReg() && "ADD32ri op 0 must be reg");
    assert(MI.getOperand(2).isImm() && "ADD32ri op 2 must be imm");
    const Register Dst = MI.getOperand(0).getReg();
    const uint32_t Imm = static_cast<uint32_t>(MI.getOperand(2).getImm());
    const std::array<uint8_t, 4> ImmBytes = {
        static_cast<uint8_t>(Imm & 0xFFu),
        static_cast<uint8_t>((Imm >> 8) & 0xFFu),
        static_cast<uint8_t>((Imm >> 16) & 0xFFu),
        static_cast<uint8_t>((Imm >> 24) & 0xFFu),
    };

    auto Insert = MachineBasicBlock::iterator(&MI);
    const DebugLoc DL = MI.getDebugLoc();

    // PROLOGUE — spill ECX, EDX, and DST32 to scratch. Spill DST32
    // last so it captures its original value (saving ECX/EDX first
    // doesn't touch DST32).
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP)
        .addImm(Addr->SaveEcxDisp)
        .addReg(Mov::ECX);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP)
        .addImm(Addr->SaveEdxDisp)
        .addReg(Mov::EDX);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP)
        .addImm(Addr->SrcDstDisp)
        .addReg(Dst);

    // CHAIN — four per-byte stages, in increasing byte order. Each
    // stage reads the current byte of the operand from srcdst (still
    // its original value at positions ≥ ByteIdx) and writes the sum
    // back in place; the carry-out is left in CL for the next stage.
    for (unsigned ByteIdx = 0; ByteIdx < 4; ++ByteIdx)
      emitByteStageAdd(MBB, Insert, DL, TII, *Addr, ByteIdx,
                    ByteSource::fromImm(ImmBytes[ByteIdx]));

    // EPILOGUE — restore the parent regs, then reload DST32 from the
    // srcdst buffer. Order matters when DST32 happens to be ECX or
    // EDX: the restore writes the original saved value, then the
    // result load overwrites it with the actual result.
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
        .addReg(Mov::EBP)
        .addImm(Addr->SaveEcxDisp);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::EDX)
        .addReg(Mov::EBP)
        .addImm(Addr->SaveEdxDisp);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Dst)
        .addReg(Mov::EBP)
        .addImm(Addr->SrcDstDisp);

    MI.eraseFromParent();
    return true;
  }

  // Stage 7a1+ — `add DST32, DST32, RHS32` legalisation. Same byte
  // chain as legalizeADD32ri, but the RHS bytes come from a per-
  // function spill buffer (`rhs_buf`) reserved by FrameLowering when
  // ADD32rr is present, instead of being compile-time immediate
  // slices. Returns false (no rewrite) when either the base scratch
  // slots or the rhs_buf slot is missing — the latter signals that
  // FrameLowering's pre-PEI scan didn't see this ADD32rr (e.g. an
  // ADJCALLSTACKUP/DOWN lowering inserted it after the scan), and the
  // safe thing is to leave the `add reg, reg` alone.
  bool legalizeADD32rr(MachineInstr &MI, MachineBasicBlock &MBB,
                       const TargetInstrInfo &TII) const {
    const MachineFunction &MF = *MBB.getParent();
    const std::optional<EbpAddr> Addr = resolveScratchAddrs(MF);
    if (!Addr || !Addr->RhsDisp)
      return false;

    // ADD32rr operands: $dst (def, GPR32, tied to $src1), $src1 (use,
    // GPR32), $src2 (use, GPR32). RA gives us op0.reg == op1.reg
    // post-tie, and op2 is the RHS — possibly the same physreg as
    // op0 (e.g. `add eax, eax`), which is fine because we spill both
    // operands before borrowing any byte registers.
    assert(MI.getOperand(0).isReg() && "ADD32rr op 0 must be reg");
    assert(MI.getOperand(2).isReg() && "ADD32rr op 2 must be reg");
    const Register Dst = MI.getOperand(0).getReg();
    const Register Rhs = MI.getOperand(2).getReg();

    auto Insert = MachineBasicBlock::iterator(&MI);
    const DebugLoc DL = MI.getDebugLoc();
    const int64_t RhsDisp = *Addr->RhsDisp;

    // PROLOGUE — save ECX, EDX, then spill both operands. Order:
    // ECX/EDX saves first (they don't touch DST32 or RHS32), then
    // srcdst <- Dst, then rhs_buf <- Rhs. If Dst == Rhs, both spills
    // capture the same current value; legal.
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP)
        .addImm(Addr->SaveEcxDisp)
        .addReg(Mov::ECX);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP)
        .addImm(Addr->SaveEdxDisp)
        .addReg(Mov::EDX);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP)
        .addImm(Addr->SrcDstDisp)
        .addReg(Dst);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP)
        .addImm(RhsDisp)
        .addReg(Rhs);

    // CHAIN — four byte stages, RHS bytes read from rhs_buf.
    for (unsigned ByteIdx = 0; ByteIdx < 4; ++ByteIdx)
      emitByteStageAdd(MBB, Insert, DL, TII, *Addr, ByteIdx,
                    ByteSource::fromMem(RhsDisp));

    // EPILOGUE — restore ECX/EDX, then load DST32 from srcdst (same
    // ordering rationale as legalizeADD32ri: handles DST32 ∈ {ECX, EDX}).
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
        .addReg(Mov::EBP)
        .addImm(Addr->SaveEcxDisp);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::EDX)
        .addReg(Mov::EBP)
        .addImm(Addr->SaveEdxDisp);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Dst)
        .addReg(Mov::EBP)
        .addImm(Addr->SrcDstDisp);

    MI.eraseFromParent();
    return true;
  }

  // Stage 7b1 — `<bitwise32> DST32, DST32, IMM32` (AND/OR/XOR ri).
  // Same shape as legalizeADD32ri, but each byte stage is the simpler
  // single-lookup form (no carry chain), and the table symbol comes
  // from the dispatcher rather than being baked in. `TableSym` is one
  // of `__mov_and8_table`, `__mov_or8_table`, `__mov_xor8_table`.
  bool legalizeBitwise32ri(MachineInstr &MI, MachineBasicBlock &MBB,
                           const TargetInstrInfo &TII,
                           const char *TableSym) const {
    const MachineFunction &MF = *MBB.getParent();
    const std::optional<EbpAddr> Addr = resolveScratchAddrs(MF);
    if (!Addr)
      return false;

    assert(MI.getOperand(0).isReg() && "bitwise32ri op 0 must be reg");
    assert(MI.getOperand(2).isImm() && "bitwise32ri op 2 must be imm");
    const Register Dst = MI.getOperand(0).getReg();
    const uint32_t Imm = static_cast<uint32_t>(MI.getOperand(2).getImm());
    const std::array<uint8_t, 4> ImmBytes = {
        static_cast<uint8_t>(Imm & 0xFFu),
        static_cast<uint8_t>((Imm >> 8) & 0xFFu),
        static_cast<uint8_t>((Imm >> 16) & 0xFFu),
        static_cast<uint8_t>((Imm >> 24) & 0xFFu),
    };

    auto Insert = MachineBasicBlock::iterator(&MI);
    const DebugLoc DL = MI.getDebugLoc();

    // PROLOGUE — same as ADD32ri: save ECX, EDX, spill DST32.
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP).addImm(Addr->SaveEcxDisp).addReg(Mov::ECX);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP).addImm(Addr->SaveEdxDisp).addReg(Mov::EDX);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP).addImm(Addr->SrcDstDisp).addReg(Dst);

    // CHAIN — four independent byte stages, each a single table lookup.
    for (unsigned ByteIdx = 0; ByteIdx < 4; ++ByteIdx)
      emitByteStageBitwise(MBB, Insert, DL, TII, *Addr, ByteIdx,
                           ByteSource::fromImm(ImmBytes[ByteIdx]), TableSym);

    // EPILOGUE — same restore order as ADD32ri.
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
        .addReg(Mov::EBP).addImm(Addr->SaveEcxDisp);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::EDX)
        .addReg(Mov::EBP).addImm(Addr->SaveEdxDisp);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Dst)
        .addReg(Mov::EBP).addImm(Addr->SrcDstDisp);

    MI.eraseFromParent();
    return true;
  }

  // Stage 7b1 — `<bitwise32> DST32, DST32, RHS32` (AND/OR/XOR rr).
  // Same shape as legalizeADD32rr (rhs_buf spill + per-byte memory
  // read), but byte-stage form is the bitwise single-lookup.
  bool legalizeBitwise32rr(MachineInstr &MI, MachineBasicBlock &MBB,
                           const TargetInstrInfo &TII,
                           const char *TableSym) const {
    const MachineFunction &MF = *MBB.getParent();
    const std::optional<EbpAddr> Addr = resolveScratchAddrs(MF);
    if (!Addr || !Addr->RhsDisp)
      return false;

    assert(MI.getOperand(0).isReg() && "bitwise32rr op 0 must be reg");
    assert(MI.getOperand(2).isReg() && "bitwise32rr op 2 must be reg");
    const Register Dst = MI.getOperand(0).getReg();
    const Register Rhs = MI.getOperand(2).getReg();

    auto Insert = MachineBasicBlock::iterator(&MI);
    const DebugLoc DL = MI.getDebugLoc();
    const int64_t RhsDisp = *Addr->RhsDisp;

    // PROLOGUE — save ECX, EDX, spill both operands. Same ordering
    // rationale as ADD32rr (Dst == Rhs is fine — both spills capture
    // the current value before any byte register is borrowed).
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP).addImm(Addr->SaveEcxDisp).addReg(Mov::ECX);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP).addImm(Addr->SaveEdxDisp).addReg(Mov::EDX);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP).addImm(Addr->SrcDstDisp).addReg(Dst);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP).addImm(RhsDisp).addReg(Rhs);

    for (unsigned ByteIdx = 0; ByteIdx < 4; ++ByteIdx)
      emitByteStageBitwise(MBB, Insert, DL, TII, *Addr, ByteIdx,
                           ByteSource::fromMem(RhsDisp), TableSym);

    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
        .addReg(Mov::EBP).addImm(Addr->SaveEcxDisp);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::EDX)
        .addReg(Mov::EBP).addImm(Addr->SaveEdxDisp);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Dst)
        .addReg(Mov::EBP).addImm(Addr->SrcDstDisp);

    MI.eraseFromParent();
    return true;
  }

  // Stage 7b2: shift direction tag for legalizeShift32ri.
  enum class ShiftDir { SHL, SHR, SAR };

  // Helper: load a "byte source" into a given low-byte register
  // (Mov::DL or Mov::CL), choosing between three shapes:
  //   - immediate (zero or sign byte)
  //   - load from srcdst[Idx]   (when Idx is in [0, 3])
  //   - load from sign_buf       (used for SAR's high-side OOR substitution)
  // Returns nothing; the target reg has the byte after the call.
  enum class ByteSrc { FromBuf, FromSignBuf, ConstZero };
  // Generalised byte-source loader. `BufBaseDisp` is the EBP-relative
  // displacement of the buffer to read from (e.g. `A.SrcDstDisp` for
  // the ri in-place flow, `A.ShiftedBufDisp` for rCL's per-stage
  // shifted-value buffer). `Idx` is the byte offset within that buf.
  static void emitLoadByteSrc(MachineBasicBlock &MBB,
                              MachineBasicBlock::iterator I,
                              const DebugLoc &DL, const TargetInstrInfo &TII,
                              const EbpAddr &A, ByteSrc Src,
                              int64_t BufBaseDisp, int Idx,
                              Register TargetByteReg) {
    switch (Src) {
    case ByteSrc::FromBuf:
      // mov <reg>, byte ptr [<buf_base> + Idx]
      BuildMI(MBB, I, DL, TII.get(Mov::MOV8rm), TargetByteReg)
          .addReg(Mov::EBP)
          .addImm(BufBaseDisp + static_cast<int64_t>(Idx));
      break;
    case ByteSrc::FromSignBuf:
      assert(A.SignBufDisp && "FromSignBuf requires a reserved sign-buf slot");
      // mov <reg>, byte ptr [sign_buf]
      BuildMI(MBB, I, DL, TII.get(Mov::MOV8rm), TargetByteReg)
          .addReg(Mov::EBP)
          .addImm(*A.SignBufDisp);
      break;
    case ByteSrc::ConstZero:
      // mov <reg>, 0
      BuildMI(MBB, I, DL, TII.get(Mov::MOV8ri), TargetByteReg).addImm(0);
      break;
    }
  }

  // Helper: emit a unary byte table lookup.
  //   1. mov ecx, 0
  //   2. mov [idx], ecx                 ; zero the 4-byte idx slot
  //   3. mov [idx + 0], <input_byte>    ; idx[0] = input byte, idx[1..3] = 0
  //   4. mov ecx, [idx]                 ; ECX = input byte (low byte) | 0
  //   5. mov <output_reg>, [<TableSym> + ecx]
  // After this returns, <output_reg> has the table result; ECX is
  // clobbered (low byte = table result). The caller is responsible
  // for getting the input byte into <input_byte_reg> before calling.
  static void emitUnaryByteLookup(MachineBasicBlock &MBB,
                                  MachineBasicBlock::iterator I,
                                  const DebugLoc &DL,
                                  const TargetInstrInfo &TII,
                                  const EbpAddr &A, Register InputByteReg,
                                  const char *TableSym,
                                  Register OutputByteReg) {
    // Zero the 4-byte idx slot in one instruction (no ECX clobber).
    BuildMI(MBB, I, DL, TII.get(Mov::MOV32mi))
        .addReg(Mov::EBP).addImm(A.IdxDisp).addImm(0);
    BuildMI(MBB, I, DL, TII.get(Mov::MOV8mr))
        .addReg(Mov::EBP).addImm(A.IdxDisp).addReg(InputByteReg);
    BuildMI(MBB, I, DL, TII.get(Mov::MOV32rm), Mov::ECX)
        .addReg(Mov::EBP).addImm(A.IdxDisp);
    BuildMI(MBB, I, DL, TII.get(Mov::MOV8rm_idx), OutputByteReg)
        .addExternalSymbol(TableSym).addReg(Mov::ECX);
  }

  // Helper: emit `srcdst[ByteIdx] = OR(low_contrib, high_contrib)`,
  // assuming the *low* contribution has been pre-stashed at
  // `srcdst[ByteIdx]` and the *high* contribution is currently in
  // DL. The reason for the asymmetry: between the two table lookups
  // we have to clobber ECX (which contains CL = low_contrib), so the
  // low byte gets parked in memory. The caller flow:
  //
  //   1. compute low_contrib into DL, then `mov [srcdst+i], DL`
  //   2. compute high_contrib into DL (this clobbers ECX freely)
  //   3. emitOrByteAndStore — reads low_contrib back into CL, packs
  //      (CL, DL) into idx[1..0], looks up the OR table, and writes
  //      the result back to srcdst[ByteIdx].
  //
  // After this returns, srcdst[ByteIdx] holds the final result byte.
  // ECX/DL/CL are trashed. idx is left in a clobbered state (the
  // caller's next byte-stage zero pass resets it).
  static void emitOrByteAndStore(MachineBasicBlock &MBB,
                                 MachineBasicBlock::iterator I,
                                 const DebugLoc &DL,
                                 const TargetInstrInfo &TII,
                                 const EbpAddr &A, int64_t DstBufDisp,
                                 unsigned ByteIdx) {
    // mov cl, byte ptr [<dst_buf> + i]   ; recover low_contrib into CL
    BuildMI(MBB, I, DL, TII.get(Mov::MOV8rm), Mov::CL)
        .addReg(Mov::EBP)
        .addImm(DstBufDisp + static_cast<int64_t>(ByteIdx));
    // mov byte ptr [idx + 0], dl       ; idx[0] = high_contrib
    BuildMI(MBB, I, DL, TII.get(Mov::MOV8mr))
        .addReg(Mov::EBP).addImm(A.IdxDisp).addReg(Mov::DL);
    // mov byte ptr [idx + 1], cl       ; idx[1] = low_contrib
    BuildMI(MBB, I, DL, TII.get(Mov::MOV8mr))
        .addReg(Mov::EBP).addImm(A.IdxDisp + 1).addReg(Mov::CL);
    // idx[2..3] are 0 from the previous lookup's `mov [idx], ecx`
    // zero pass (the last write to idx[2..3] before this point is
    // the one in emitUnaryByteLookup, which set them to 0).
    // mov ecx, dword ptr [idx]
    BuildMI(MBB, I, DL, TII.get(Mov::MOV32rm), Mov::ECX)
        .addReg(Mov::EBP).addImm(A.IdxDisp);
    // mov dl, byte ptr [__mov_or8_table + ecx]
    BuildMI(MBB, I, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
        .addExternalSymbol("__mov_or8_table").addReg(Mov::ECX);
    // mov byte ptr [<dst_buf> + i], dl
    BuildMI(MBB, I, DL, TII.get(Mov::MOV8mr))
        .addReg(Mov::EBP)
        .addImm(DstBufDisp + static_cast<int64_t>(ByteIdx))
        .addReg(Mov::DL);
  }

  // Helper: emit `mov byte ptr [<dst_buf> + ByteIdx], dl` — the
  // single-byte stash used by emitShiftByteStage to park the low
  // contribution before computing the high contribution.
  static void emitStashLowContrib(MachineBasicBlock &MBB,
                                  MachineBasicBlock::iterator I,
                                  const DebugLoc &DL,
                                  const TargetInstrInfo &TII,
                                  const EbpAddr & /*A*/, int64_t DstBufDisp,
                                  unsigned ByteIdx) {
    BuildMI(MBB, I, DL, TII.get(Mov::MOV8mr))
        .addReg(Mov::EBP)
        .addImm(DstBufDisp + static_cast<int64_t>(ByteIdx))
        .addReg(Mov::DL);
  }

  // Stage 7b2 per-byte legalization. Computes the result byte at
  // result_idx from the two source byte positions inside srcdst,
  // applying `LowTableSym` to the low source and `HighTableSym` to
  // the high source. OOR sources (out of [0, 3]) are substituted
  // with either 0 or the SAR sign byte (for arithmetic shifts).
  //
  // Special-cases:
  //   - bit_shift == 0 callers use `emitShiftWholeByteStage` instead.
  //     This helper assumes both tables are non-null.
  //   - LowSrcIdx == ResultIdx is fine; the read happens before the
  //     stash, so we don't lose the byte. The processing-order
  //     contract (high-to-low for SHL, low-to-high for SHR/SAR) keeps
  //     the *other* source position (HighSrcIdx for SHL, etc.) safe.
  static void emitShiftByteStage(MachineBasicBlock &MBB,
                                 MachineBasicBlock::iterator I,
                                 const DebugLoc &DL,
                                 const TargetInstrInfo &TII,
                                 const EbpAddr &A, int64_t SrcBufDisp,
                                 int64_t DstBufDisp, unsigned ResultIdx,
                                 int LowSrcIdx, int HighSrcIdx,
                                 const char *LowTableSym,
                                 const char *HighTableSym, bool OorIsSign) {
    auto srcForIdx = [&](int Idx) -> ByteSrc {
      if (Idx >= 0 && Idx <= 3)
        return ByteSrc::FromBuf;
      return OorIsSign ? ByteSrc::FromSignBuf : ByteSrc::ConstZero;
    };

    // (1) low_contrib: load low source byte into DL, optionally
    // shift via LowTableSym, then stash to dst[ResultIdx].
    const ByteSrc LowSrc = srcForIdx(LowSrcIdx);
    if (LowTableSym) {
      emitLoadByteSrc(MBB, I, DL, TII, A, LowSrc, SrcBufDisp, LowSrcIdx,
                      Mov::DL);
      emitUnaryByteLookup(MBB, I, DL, TII, A, Mov::DL, LowTableSym, Mov::DL);
    } else {
      // No shift needed (bit_shift effectively 0 for this contribution —
      // shouldn't happen in this helper; included for completeness).
      emitLoadByteSrc(MBB, I, DL, TII, A, LowSrc, SrcBufDisp, LowSrcIdx,
                      Mov::DL);
    }
    emitStashLowContrib(MBB, I, DL, TII, A, DstBufDisp, ResultIdx);

    // (2) high_contrib: load high source byte into DL, optionally
    // shift via HighTableSym. Result stays in DL.
    const ByteSrc HighSrc = srcForIdx(HighSrcIdx);
    if (HighTableSym) {
      emitLoadByteSrc(MBB, I, DL, TII, A, HighSrc, SrcBufDisp, HighSrcIdx,
                      Mov::DL);
      emitUnaryByteLookup(MBB, I, DL, TII, A, Mov::DL, HighTableSym, Mov::DL);
    } else {
      emitLoadByteSrc(MBB, I, DL, TII, A, HighSrc, SrcBufDisp, HighSrcIdx,
                      Mov::DL);
    }

    // (3) OR low_contrib (stashed at dst[ResultIdx]) and
    // high_contrib (in DL), store final byte to dst[ResultIdx].
    emitOrByteAndStore(MBB, I, DL, TII, A, DstBufDisp, ResultIdx);
  }

  // Stage 7b2 — `<shift> DST32, DST32, IMM5` mov-only legalisation.
  // SHL/SHR/SAR ri all funnel through here; the dispatcher passes
  // `Dir` to pick the per-byte source positions and tables.
  //
  // amt is masked to 5 bits (matching x86's hardware behaviour);
  // `bit_shift == 0` is special-cased to avoid undefined-behaviour
  // shifts by 8 and to skip the lookups (it's a whole-byte move).
  bool legalizeShift32ri(MachineInstr &MI, MachineBasicBlock &MBB,
                         const TargetInstrInfo &TII, ShiftDir Dir) const {
    const MachineFunction &MF = *MBB.getParent();
    const std::optional<EbpAddr> Addr = resolveScratchAddrs(MF);
    if (!Addr)
      return false;
    if (Dir == ShiftDir::SAR && !Addr->SignBufDisp)
      return false;

    assert(MI.getOperand(0).isReg() && "shift32ri op 0 must be reg");
    assert(MI.getOperand(2).isImm() && "shift32ri op 2 must be imm");
    const Register Dst = MI.getOperand(0).getReg();
    const unsigned Amt =
        static_cast<unsigned>(MI.getOperand(2).getImm()) & 31u;
    if (Amt == 0) {
      // shift by 0 is a no-op — erase and move on.
      MI.eraseFromParent();
      return true;
    }
    const unsigned ByteShift = Amt / 8;
    const unsigned BitShift = Amt % 8;
    const bool IsSAR = (Dir == ShiftDir::SAR);

    auto Insert = MachineBasicBlock::iterator(&MI);
    const DebugLoc DL = MI.getDebugLoc();

    // PROLOGUE — save ECX/EDX, spill DST32 to srcdst.
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP).addImm(Addr->SaveEcxDisp).addReg(Mov::ECX);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP).addImm(Addr->SaveEdxDisp).addReg(Mov::EDX);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP).addImm(Addr->SrcDstDisp).addReg(Dst);

    // For SAR: compute the sign byte once (0x00 or 0xFF) from the
    // top byte of the original operand, store it in sign_buf. Every
    // out-of-range high-side source byte in the chain below pulls
    // from this slot.
    if (IsSAR) {
      // mov dl, byte ptr [srcdst + 3]
      BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
          .addReg(Mov::EBP).addImm(Addr->SrcDstDisp + 3);
      emitUnaryByteLookup(MBB, Insert, DL, TII, *Addr, Mov::DL,
                          "__mov_sar_sign_byte", Mov::DL);
      // mov byte ptr [sign_buf], dl
      BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
          .addReg(Mov::EBP).addImm(*Addr->SignBufDisp).addReg(Mov::DL);
    }

    // Per-byte stages.
    //
    // SHL processes high → low because each result byte depends on
    // source positions ≤ itself, and writes to srcdst[i] would
    // destroy the original byte at position i if we hadn't already
    // read it. SHR/SAR is the mirror: process low → high.
    const char *ShlTables[8] = {
        nullptr,             // k=0 unused
        "__mov_shl_byte_1",
        "__mov_shl_byte_2",
        "__mov_shl_byte_3",
        "__mov_shl_byte_4",
        "__mov_shl_byte_5",
        "__mov_shl_byte_6",
        "__mov_shl_byte_7",
    };
    const char *ShrTables[8] = {
        nullptr,             // k=0 unused
        "__mov_shr_byte_1",
        "__mov_shr_byte_2",
        "__mov_shr_byte_3",
        "__mov_shr_byte_4",
        "__mov_shr_byte_5",
        "__mov_shr_byte_6",
        "__mov_shr_byte_7",
    };

    const bool IsSHL = (Dir == ShiftDir::SHL);

    auto processByte = [&](unsigned i) {
      const int LowSrcIdx = IsSHL ? (static_cast<int>(i) -
                                     static_cast<int>(ByteShift))
                                  : (static_cast<int>(i) +
                                     static_cast<int>(ByteShift));
      const int HighSrcIdx = IsSHL
                                 ? (LowSrcIdx - 1)
                                 : (LowSrcIdx + 1);

      if (BitShift == 0) {
        // Whole-byte move: result[i] = orig[LowSrcIdx] (no shift).
        // No table lookup; just one MOV8mr from srcdst[LowSrcIdx] to
        // srcdst[i] via DL, or substitute 0 / sign_byte for OOR.
        ByteSrc Src = (LowSrcIdx >= 0 && LowSrcIdx <= 3)
                          ? ByteSrc::FromBuf
                          : (IsSAR ? ByteSrc::FromSignBuf
                                   : ByteSrc::ConstZero);
        emitLoadByteSrc(MBB, Insert, DL, TII, *Addr, Src, Addr->SrcDstDisp,
                        LowSrcIdx, Mov::DL);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
            .addReg(Mov::EBP)
            .addImm(Addr->SrcDstDisp + static_cast<int64_t>(i))
            .addReg(Mov::DL);
        return;
      }

      // bit_shift > 0: 2 unary lookups + OR. Pick the table direction
      // based on which side this contribution comes from. ri legalize
      // is in-place: src and dst bufs are both srcdst.
      const char *LowTab = IsSHL ? ShlTables[BitShift]
                                 : ShrTables[BitShift];
      const char *HighTab = IsSHL ? ShrTables[8 - BitShift]
                                  : ShlTables[8 - BitShift];
      emitShiftByteStage(MBB, Insert, DL, TII, *Addr, Addr->SrcDstDisp,
                         Addr->SrcDstDisp, i, LowSrcIdx, HighSrcIdx, LowTab,
                         HighTab, IsSAR);
    };

    if (IsSHL) {
      processByte(3);
      processByte(2);
      processByte(1);
      processByte(0);
    } else {
      processByte(0);
      processByte(1);
      processByte(2);
      processByte(3);
    }

    // EPILOGUE — restore ECX/EDX, load DST32 from srcdst.
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
        .addReg(Mov::EBP).addImm(Addr->SaveEcxDisp);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::EDX)
        .addReg(Mov::EBP).addImm(Addr->SaveEdxDisp);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Dst)
        .addReg(Mov::EBP).addImm(Addr->SrcDstDisp);

    MI.eraseFromParent();
    return true;
  }

  // Stage 7b3 — `<shift> DST32, DST32, CL` mov-only legalisation.
  // The shift amount is a runtime value in CL (via the SHL/SHR/SAR
  // 32rCL opcode's `Uses=[ECX]` constraint). We can't dispatch off
  // it at codegen time, so we unroll a 5-stage power-of-2 chain:
  //
  //   for k in 0..4:
  //     shifted_buf = srcdst <shift by 2^k>     ; always compute
  //     mask = (amount & (1<<k)) ? 0xFF : 0x00 ; runtime
  //     srcdst = (mask & shifted_buf) | (~mask & srcdst)
  //
  // After 5 stages, srcdst holds `dst << (amount & 31)` (or the
  // shr/sar variant). The mask-based select is the only mov-only way
  // to express conditional update — branches don't exist at this
  // point. Per-byte select: 2 AND lookups + 1 OR via the existing
  // bitwise tables (added at stage 7b1), plus 1 XOR for ~mask.
  //
  // CL holds the amount on entry from the SelectionDAGISel-inserted
  // `CopyToReg ECX`. It MUST be spilled to amount_buf before the
  // first ECX clobber, or the runtime count is lost.
  bool legalizeShift32rCL(MachineInstr &MI, MachineBasicBlock &MBB,
                          const TargetInstrInfo &TII, ShiftDir Dir) const {
    const MachineFunction &MF = *MBB.getParent();
    const std::optional<EbpAddr> Addr = resolveScratchAddrs(MF);
    if (!Addr || !Addr->AmountBufDisp || !Addr->ShiftedBufDisp)
      return false;
    if (Dir == ShiftDir::SAR && !Addr->SignBufDisp)
      return false;

    assert(MI.getOperand(0).isReg() && "shift32rCL op 0 must be reg");
    const Register Dst = MI.getOperand(0).getReg();

    auto Insert = MachineBasicBlock::iterator(&MI);
    const DebugLoc DL = MI.getDebugLoc();
    const bool IsSHL = (Dir == ShiftDir::SHL);
    const bool IsSAR = (Dir == ShiftDir::SAR);

    // PROLOGUE — order matters:
    //   1. Save CL to amount_buf[0] FIRST, before touching ECX.
    //   2. Spill ECX, EDX.
    //   3. Spill Dst to srcdst.
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
        .addReg(Mov::EBP).addImm(*Addr->AmountBufDisp).addReg(Mov::CL);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP).addImm(Addr->SaveEcxDisp).addReg(Mov::ECX);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP).addImm(Addr->SaveEdxDisp).addReg(Mov::EDX);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP).addImm(Addr->SrcDstDisp).addReg(Dst);

    // SAR sign byte — computed once from the *original* top byte
    // (before any stage updates srcdst).
    if (IsSAR) {
      BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
          .addReg(Mov::EBP).addImm(Addr->SrcDstDisp + 3);
      emitUnaryByteLookup(MBB, Insert, DL, TII, *Addr, Mov::DL,
                          "__mov_sar_sign_byte", Mov::DL);
      BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
          .addReg(Mov::EBP).addImm(*Addr->SignBufDisp).addReg(Mov::DL);
    }

    // Shift table maps (same as ri legalize).
    const char *ShlTables[8] = {
        nullptr, "__mov_shl_byte_1", "__mov_shl_byte_2", "__mov_shl_byte_3",
        "__mov_shl_byte_4", "__mov_shl_byte_5", "__mov_shl_byte_6",
        "__mov_shl_byte_7",
    };
    const char *ShrTables[8] = {
        nullptr, "__mov_shr_byte_1", "__mov_shr_byte_2", "__mov_shr_byte_3",
        "__mov_shr_byte_4", "__mov_shr_byte_5", "__mov_shr_byte_6",
        "__mov_shr_byte_7",
    };

    // ===== 5-stage unroll =====
    for (unsigned k = 0; k < 5; ++k) {
      const unsigned ShiftAmount = 1u << k; // 1, 2, 4, 8, 16

      // ----- (A) Compute shifted_buf = (srcdst shifted by ShiftAmount) -----
      if (ShiftAmount < 8) {
        // Sub-byte shift: bit_shift = ShiftAmount, byte_shift = 0.
        const unsigned BitShift = ShiftAmount;
        const char *LowTab = IsSHL ? ShlTables[BitShift] : ShrTables[BitShift];
        const char *HighTab =
            IsSHL ? ShrTables[8 - BitShift] : ShlTables[8 - BitShift];

        auto processOneByte = [&](unsigned i) {
          const int LowSrcIdx = static_cast<int>(i);
          const int HighSrcIdx = IsSHL ? (LowSrcIdx - 1) : (LowSrcIdx + 1);
          emitShiftByteStage(MBB, Insert, DL, TII, *Addr, Addr->SrcDstDisp,
                             *Addr->ShiftedBufDisp, i, LowSrcIdx, HighSrcIdx,
                             LowTab, HighTab, IsSAR);
        };
        // src and dst bufs are different here, so processing order
        // doesn't matter — pick the ri-style order for consistency.
        if (IsSHL) {
          processOneByte(3); processOneByte(2);
          processOneByte(1); processOneByte(0);
        } else {
          processOneByte(0); processOneByte(1);
          processOneByte(2); processOneByte(3);
        }
      } else {
        // Whole-byte shift: byte_shift = ShiftAmount / 8 (1 or 2),
        // bit_shift = 0. No table lookups needed.
        const int ByteShift = static_cast<int>(ShiftAmount / 8);
        for (unsigned i = 0; i < 4; ++i) {
          const int SrcIdx = IsSHL ? (static_cast<int>(i) - ByteShift)
                                   : (static_cast<int>(i) + ByteShift);
          // Load source byte into DL (or OOR substitute).
          if (SrcIdx >= 0 && SrcIdx <= 3) {
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
                .addReg(Mov::EBP)
                .addImm(Addr->SrcDstDisp + static_cast<int64_t>(SrcIdx));
          } else if (IsSAR) {
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
                .addReg(Mov::EBP).addImm(*Addr->SignBufDisp);
          } else {
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8ri), Mov::DL).addImm(0);
          }
          // Store to shifted_buf[i].
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
              .addReg(Mov::EBP)
              .addImm(*Addr->ShiftedBufDisp + static_cast<int64_t>(i))
              .addReg(Mov::DL);
        }
      }

      // ----- (B) Compute mask = (amount & (1<<k)) ? 0xFF : 0x00 -----
      // 1. amount_byte → DL
      BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
          .addReg(Mov::EBP).addImm(*Addr->AmountBufDisp);
      // 2. Pack (amount, 1<<k) into idx[1..0] and look up __mov_and8_table.
      emitIdxZero(MBB, Insert, DL, TII, *Addr);
      BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
          .addReg(Mov::EBP).addImm(Addr->IdxDisp + 1).addReg(Mov::DL);
      BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8ri), Mov::DL)
          .addImm(static_cast<int64_t>(1u << k));
      BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
          .addReg(Mov::EBP).addImm(Addr->IdxDisp).addReg(Mov::DL);
      BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
          .addReg(Mov::EBP).addImm(Addr->IdxDisp);
      BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
          .addExternalSymbol("__mov_and8_table").addReg(Mov::ECX);
      // 3. select_mask_table[DL] → DL (non-zero → 0xFF, zero → 0x00).
      emitUnaryByteLookup(MBB, Insert, DL, TII, *Addr, Mov::DL,
                          "__mov_select_mask_table", Mov::DL);
      // 4. Stash mask at amount_buf[1] for stable per-byte access.
      BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
          .addReg(Mov::EBP)
          .addImm(*Addr->AmountBufDisp + 1)
          .addReg(Mov::DL);
      // 5. Compute inv_mask = mask XOR 0xFF (using __mov_xor8_table)
      //    and stash at amount_buf[2].
      emitIdxZero(MBB, Insert, DL, TII, *Addr);
      BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
          .addReg(Mov::EBP).addImm(Addr->IdxDisp + 1).addReg(Mov::DL);
      BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8ri), Mov::DL).addImm(0xFF);
      BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
          .addReg(Mov::EBP).addImm(Addr->IdxDisp).addReg(Mov::DL);
      BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
          .addReg(Mov::EBP).addImm(Addr->IdxDisp);
      BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
          .addExternalSymbol("__mov_xor8_table").addReg(Mov::ECX);
      BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
          .addReg(Mov::EBP)
          .addImm(*Addr->AmountBufDisp + 2)
          .addReg(Mov::DL);

      // ----- (C) Per-byte select:
      //         srcdst[i] = (mask & shifted_buf[i]) | (~mask & srcdst[i])
      // For each byte, we compute the inv_mask AND-merge first
      // (consuming srcdst[i] before we overwrite it), then the mask
      // AND-merge, then OR them via the existing emitOrByteAndStore
      // (which expects low_contrib parked at dst[i] and high_contrib
      // in DL).
      for (unsigned i = 0; i < 4; ++i) {
        // (C1) Compute (~mask & srcdst[i]) → DL, stash to srcdst[i].
        emitIdxZero(MBB, Insert, DL, TII, *Addr);
        // idx[1] = inv_mask
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
            .addReg(Mov::EBP).addImm(*Addr->AmountBufDisp + 2);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
            .addReg(Mov::EBP).addImm(Addr->IdxDisp + 1).addReg(Mov::DL);
        // idx[0] = srcdst[i]
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
            .addReg(Mov::EBP)
            .addImm(Addr->SrcDstDisp + static_cast<int64_t>(i));
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
            .addReg(Mov::EBP).addImm(Addr->IdxDisp).addReg(Mov::DL);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
            .addReg(Mov::EBP).addImm(Addr->IdxDisp);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
            .addExternalSymbol("__mov_and8_table").addReg(Mov::ECX);
        // Stash to srcdst[i].
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
            .addReg(Mov::EBP)
            .addImm(Addr->SrcDstDisp + static_cast<int64_t>(i))
            .addReg(Mov::DL);

        // (C2) Compute (mask & shifted_buf[i]) → DL.
        emitIdxZero(MBB, Insert, DL, TII, *Addr);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
            .addReg(Mov::EBP).addImm(*Addr->AmountBufDisp + 1);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
            .addReg(Mov::EBP).addImm(Addr->IdxDisp + 1).addReg(Mov::DL);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
            .addReg(Mov::EBP)
            .addImm(*Addr->ShiftedBufDisp + static_cast<int64_t>(i));
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
            .addReg(Mov::EBP).addImm(Addr->IdxDisp).addReg(Mov::DL);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
            .addReg(Mov::EBP).addImm(Addr->IdxDisp);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
            .addExternalSymbol("__mov_and8_table").addReg(Mov::ECX);

        // (C3) OR the stashed inv_mask & srcdst (at srcdst[i]) with the
        // mask & shifted_buf (in DL), write final to srcdst[i].
        emitOrByteAndStore(MBB, Insert, DL, TII, *Addr, Addr->SrcDstDisp, i);
      }
    }

    // EPILOGUE — restore ECX/EDX, load Dst from srcdst.
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
        .addReg(Mov::EBP).addImm(Addr->SaveEcxDisp);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::EDX)
        .addReg(Mov::EBP).addImm(Addr->SaveEdxDisp);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Dst)
        .addReg(Mov::EBP).addImm(Addr->SrcDstDisp);

    MI.eraseFromParent();
    return true;
  }
};
} // namespace

char MovOnlyLegalize::ID = 0;

FunctionPass *llvm::createMovOnlyLegalizePass() {
  return new MovOnlyLegalize();
}
