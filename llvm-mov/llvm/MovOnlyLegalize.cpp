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
#include "llvm/CodeGen/LivePhysRegs.h"
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

    // Stage 7d1: epilogue tail (`pop ebp; ret`) → mov-only sequence
    // that stashes the return address in `__mov_return_addr_slot`,
    // restores caller's EBP, adjusts ESP, and jumps via the slot.
    // Runs BEFORE the per-MI byte-chain loop so the byte-chain ADD
    // ESP, 8 emitted inline gets seen as already-lowered MovInst
    // sequences (uses MOV32mr/MOV32rm/MOV8rm_idx etc., not ADD32ri).
    Changed |= legalizeRetEpilogueTail(MF, TII);

    // Stage 7d2: prologue head (`push ebp`) → mov-only sequence that
    // saves ebp_caller to [esp - 4] and decrements ESP by 4 via a
    // hand-rolled byte SUB chain using ESP-relative scratch (we can't
    // use the usual [ebp + …] scratch yet because the original `mov
    // ebp, esp` hasn't run — EBP still holds the caller's value).
    Changed |= legalizePushEbpPrologue(MF, TII);

    // Stage 7d3: each `CALL32d` rewrites into a mov-only sequence
    // that stores the return-address label at [esp - 4], decrements
    // ESP by 4, and falls into a direct `JMP32d_CALL <callee>`. The
    // MBB is split right after the CALL so the continuation has its
    // own symbol — that label is the return target the callee will
    // jmp back to via the 7d1 `__mov_return_addr_slot` machinery.
    Changed |= legalizeCallSites(MF, TII);

    // Stage 6b — expand bare FrameIndex materializations. Each
    // LEA32r emitted by ISel for ISD::FrameIndex (e.g. `&local`
    // passed by-pointer to a callee) is rewritten into
    //     mov dst, ebp
    //     add dst, disp                   ; goes through ADD32ri
    // where `disp` is the EBP-relative offset that eliminateFrameIndex
    // resolved. Runs BEFORE the per-MI loop so the inserted ADD32ri
    // is picked up by the byte-chain rewrite below (and the disp==0
    // shape is handled there by the existing opt-3 fold).
    Changed |= legalizeLEA32rs(MF, TII);

    for (MachineBasicBlock &MBB : MF) {
      for (MachineInstr &MI : llvm::make_early_inc_range(MBB)) {
        switch (MI.getOpcode()) {
        case Mov::ADD32ri:
          // opt 3 — `add reg, 0` is a no-op; erase the MI to avoid
          // paying ~51 movs for nothing. LLVM IR optimisations usually
          // fold this away, but defensive code can leave it.
          if (MI.getOperand(2).getImm() == 0) {
            MI.eraseFromParent();
            Changed = true;
            break;
          }
          Changed |= legalizeADD32ri(MI, MBB, TII);
          break;
        case Mov::ADD32rr:
          Changed |= legalizeADD32rr(MI, MBB, TII);
          break;
        case Mov::SUB32ri:
          // Stage 7d0. `sub reg, 0` is a no-op (consistent with the
          // ADD32ri opt 3 fold).
          if (MI.getOperand(2).getImm() == 0) {
            MI.eraseFromParent();
            Changed = true;
            break;
          }
          Changed |= legalizeSUB32ri(MI, MBB, TII);
          break;
        case Mov::AND32ri:
          // opt 3 — `and reg, 0` zeroes Dst; `and reg, ~0` is a no-op.
          if (MI.getOperand(2).getImm() == 0) {
            BuildMI(MBB, MachineBasicBlock::iterator(&MI),
                    MI.getDebugLoc(), TII.get(Mov::MOV32ri),
                    MI.getOperand(0).getReg())
                .addImm(0);
            MI.eraseFromParent();
            Changed = true;
            break;
          }
          if (static_cast<uint32_t>(MI.getOperand(2).getImm()) == 0xFFFFFFFFu) {
            MI.eraseFromParent();
            Changed = true;
            break;
          }
          Changed |= legalizeBitwise32ri(MI, MBB, TII, "__mov_and8_table");
          break;
        case Mov::AND32rr:
          Changed |= legalizeBitwise32rr(MI, MBB, TII, "__mov_and8_table");
          break;
        case Mov::OR32ri:
          // opt 3 — `or reg, 0` is a no-op; `or reg, ~0` sets Dst to ~0.
          if (MI.getOperand(2).getImm() == 0) {
            MI.eraseFromParent();
            Changed = true;
            break;
          }
          if (static_cast<uint32_t>(MI.getOperand(2).getImm()) == 0xFFFFFFFFu) {
            BuildMI(MBB, MachineBasicBlock::iterator(&MI),
                    MI.getDebugLoc(), TII.get(Mov::MOV32ri),
                    MI.getOperand(0).getReg())
                .addImm(-1);
            MI.eraseFromParent();
            Changed = true;
            break;
          }
          Changed |= legalizeBitwise32ri(MI, MBB, TII, "__mov_or8_table");
          break;
        case Mov::OR32rr:
          Changed |= legalizeBitwise32rr(MI, MBB, TII, "__mov_or8_table");
          break;
        case Mov::XOR32ri:
          // opt 3 — `xor reg, 0` is a no-op. (`xor reg, ~0` is a
          // bitwise NOT and would need a separate mov-only sequence;
          // not folded here.)
          if (MI.getOperand(2).getImm() == 0) {
            MI.eraseFromParent();
            Changed = true;
            break;
          }
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

    // Recompute live-ins for every MBB once all rewrites have
    // settled. The byte-chain legalize introduces fresh uses of
    // EAX/ECX/EDX (save/restore around table lookups) inside MBBs
    // whose pre-existing live-in sets reflected the IR-level
    // register use only. Without this, -verify-machineinstrs flags
    // those new reads as "using undefined physical register". A
    // bottom-up fixed-point pass (which is what fullyRecomputeLiveIns
    // does internally) propagates correct live-ins through the
    // post-legalize CFG, including dispatcher- and call-continuation
    // MBBs added by stages 7c1 / 7d3.
    if (Changed) {
      SmallVector<MachineBasicBlock *, 16> MBBs;
      for (MachineBasicBlock &MBB : MF)
        MBBs.push_back(&MBB);
      fullyRecomputeLiveIns(MBBs);
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
          if (POp == Mov::JE || POp == Mov::JNE || POp == Mov::JB ||
              POp == Mov::JAE || POp == Mov::JBE || POp == Mov::JA ||
              POp == Mov::JL || POp == Mov::JGE || POp == Mov::JLE ||
              POp == Mov::JG) {
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
        const unsigned JccOp = Jcc->getOpcode();
        const bool IsEQ = (JccOp == Mov::JE);
        const bool IsEqOrNe = (JccOp == Mov::JE || JccOp == Mov::JNE);
        const bool IsB = (JccOp == Mov::JB);
        const bool IsAE = (JccOp == Mov::JAE);
        const bool IsBE = (JccOp == Mov::JBE);
        const bool IsA = (JccOp == Mov::JA);
        const bool IsL = (JccOp == Mov::JL);
        const bool IsGE = (JccOp == Mov::JGE);
        const bool IsLE = (JccOp == Mov::JLE);
        const bool IsG = (JccOp == Mov::JG);
        const bool IsSigned = IsL || IsGE || IsLE || IsG;
        (void)IsB; (void)IsAE; (void)IsBE; (void)IsA; // used inside if/else
        (void)IsL; // used as IsSigned discriminator

        // Save the iterator past the Jcc — we'll resume scanning there
        // after the rewrite, since the dispatcher JMP that follows is
        // left intact.
        auto NextOuter = std::next(MachineBasicBlock::iterator(Jcc));
        auto Insert = MachineBasicBlock::iterator(&CmpMI);
        const DebugLoc DL = CmpMI.getDebugLoc();

        // === PROLOGUE: save ECX/EDX, spill lhs (and rhs for rr-form) ===
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
            .addReg(Mov::EBP).addImm(Addr->SaveEcxDisp).addReg(Mov::ECX, RegState::Undef);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
            .addReg(Mov::EBP).addImm(Addr->SaveEdxDisp).addReg(Mov::EDX, RegState::Undef);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
            .addReg(Mov::EBP).addImm(Addr->SrcDstDisp).addReg(LhsReg);
        if (!IsImmRhs) {
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
              .addReg(Mov::EBP).addImm(*Addr->RhsDisp).addReg(RhsReg);
        }

        if (IsEqOrNe) {
        // === PHASE 1 (EQ/NE): in-place XOR of srcdst[i] with rhs[i] ===
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

        // === PHASE 3: compute predicate mask + invert for EQ ===
        emitUnaryByteLookup(MBB, Insert, DL, TII, *Addr, Mov::DL,
                            "__mov_select_mask_table", Mov::DL);
        if (IsEQ) {
          emitIdxZero(MBB, Insert, DL, TII, *Addr);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
              .addReg(Mov::EBP).addImm(Addr->IdxDisp + 1).addReg(Mov::DL);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mi))
              .addReg(Mov::EBP).addImm(Addr->IdxDisp).addImm(0xFF);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
              .addReg(Mov::EBP).addImm(Addr->IdxDisp);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
              .addExternalSymbol("__mov_xor8_table").addReg(Mov::ECX);
        }
        } else {
        // === SIGNED PRE-COMPUTE (a_sign, X = a_sign XOR b_sign) ===
        // Phase 1' below overwrites srcdst with diff bytes, so signed
        // predicates must capture lhs's top-byte sign BEFORE the SUB.
        // Slot layout for signed:
        //   cmp_mask_buf[0]: scratch (final mask at end)
        //   cmp_mask_buf[1]: ZF_mask → inv_mask later
        //   cmp_mask_buf[2]: a_sign mask (preserved through Phase 1'/2'/3')
        //   cmp_mask_buf[3]: X = a_sign XOR b_sign (preserved)
        if (IsSigned) {
          // a_sign = sar_sign[lhs[3]]
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
              .addReg(Mov::EBP).addImm(Addr->SrcDstDisp + 3);
          emitUnaryByteLookup(MBB, Insert, DL, TII, *Addr, Mov::DL,
                              "__mov_sar_sign_byte", Mov::DL);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
              .addReg(Mov::EBP).addImm(*Addr->CmpMaskBufDisp + 2)
              .addReg(Mov::DL);

          // X = a_sign XOR b_sign.
          if (IsImmRhs) {
            // b_sign is a compile-time constant; pack against a_sign (DL)
            // and XOR via the byte-XOR table.
            const uint8_t BSign =
                ((Imm >> 24) & 0x80u) ? 0xFFu : 0x00u;
            emitIdxZero(MBB, Insert, DL, TII, *Addr);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
                .addReg(Mov::EBP).addImm(Addr->IdxDisp + 1).addReg(Mov::DL);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8ri), Mov::DL)
                .addImm(BSign);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
                .addReg(Mov::EBP).addImm(Addr->IdxDisp).addReg(Mov::DL);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
                .addReg(Mov::EBP).addImm(Addr->IdxDisp);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
                .addExternalSymbol("__mov_xor8_table").addReg(Mov::ECX);
          } else {
            // b_sign = sar_sign[rhs[3]]
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
                .addReg(Mov::EBP).addImm(*Addr->RhsDisp + 3);
            emitUnaryByteLookup(MBB, Insert, DL, TII, *Addr, Mov::DL,
                                "__mov_sar_sign_byte", Mov::DL);
            // DL = b_sign. XOR with cmp_mask_buf[2] (a_sign).
            emitIdxZero(MBB, Insert, DL, TII, *Addr);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
                .addReg(Mov::EBP).addImm(Addr->IdxDisp + 1).addReg(Mov::DL);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
                .addReg(Mov::EBP).addImm(*Addr->CmpMaskBufDisp + 2);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
                .addReg(Mov::EBP).addImm(Addr->IdxDisp).addReg(Mov::DL);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
                .addReg(Mov::EBP).addImm(Addr->IdxDisp);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
                .addExternalSymbol("__mov_xor8_table").addReg(Mov::ECX);
          }
          // DL = X. Stash to cmp_mask_buf[3].
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
              .addReg(Mov::EBP).addImm(*Addr->CmpMaskBufDisp + 3)
              .addReg(Mov::DL);
        }

        // === PHASE 1' (B/AE/BE/A/L/GE/LE/G): byte SUB chain ===
        // srcdst[i] = lhs[i] - rhs[i] - borrow_in (CL holds borrow,
        // 0 on entry to byte 0). After the loop CL holds the final
        // borrow_out = CF (only meaningful for the unsigned predicates;
        // signed paths ignore the final-borrow stash to slot 0).
        for (unsigned i = 0; i < 4; ++i) {
          const int64_t LhsByteDisp =
              Addr->SrcDstDisp + static_cast<int64_t>(i);
          emitIdxZero(MBB, Insert, DL, TII, *Addr);
          if (i > 0) {
            // mov [idx + 2], cl  ; borrow_in from previous stage
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
                .addReg(Mov::EBP).addImm(Addr->IdxDisp + 2).addReg(Mov::CL);
          }
          // mov dl, [srcdst + i]  ; a_byte
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
              .addReg(Mov::EBP).addImm(LhsByteDisp);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
              .addReg(Mov::EBP).addImm(Addr->IdxDisp + 1).addReg(Mov::DL);
          // b_byte
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
          // Lookup diff and borrow.
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
              .addReg(Mov::EBP).addImm(Addr->IdxDisp);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
              .addExternalSymbol("__mov_sub8_diff_table").addReg(Mov::ECX);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
              .addReg(Mov::EBP).addImm(LhsByteDisp).addReg(Mov::DL);
          // CL = borrow_out. Loaded on every iteration (incl. byte 3 —
          // that's the CF byte that drives the predicate mask).
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm_idx), Mov::CL)
              .addExternalSymbol("__mov_sub8_borrow_table").addReg(Mov::ECX);
        }
        // CL = CF_byte (0 or 1). Stash to cmp_mask_buf[0] so it
        // survives the OR-reduce below (which clobbers ECX/CL).
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
            .addReg(Mov::EBP).addImm(*Addr->CmpMaskBufDisp).addReg(Mov::CL);

        // === PHASE 2': OR-reduce diff bytes into DL ===
        // Reuses the EQ/NE Phase 2 verbatim — srcdst now contains the
        // diff bytes; DL := diff_or_byte after the loop.
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
        // DL = diff_or_byte (0 iff lhs == rhs).

        // === PHASE 3': predicate-specific mask compute ===
        // Common across unsigned & signed: ZF_mask from diff_or_byte (DL).
        //   ZF_mask = (diff_or == 0) ? 0xFF : 0x00 = NOT select_mask_table[diff_or]

        // Compute ZF_mask from diff_or_byte (in DL): select_mask then XOR 0xFF.
        emitUnaryByteLookup(MBB, Insert, DL, TII, *Addr, Mov::DL,
                            "__mov_select_mask_table", Mov::DL);
        // Invert: DL = DL XOR 0xFF
        emitIdxZero(MBB, Insert, DL, TII, *Addr);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
            .addReg(Mov::EBP).addImm(Addr->IdxDisp + 1).addReg(Mov::DL);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mi))
            .addReg(Mov::EBP).addImm(Addr->IdxDisp).addImm(0xFF);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
            .addReg(Mov::EBP).addImm(Addr->IdxDisp);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
            .addExternalSymbol("__mov_xor8_table").addReg(Mov::ECX);
        // Stash ZF_mask to cmp_mask_buf[1] (free until final stash phase).
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
            .addReg(Mov::EBP).addImm(*Addr->CmpMaskBufDisp + 1).addReg(Mov::DL);

        if (IsSigned) {
          // === Signed flag math (SF, OF; ZF already at cmp_mask_buf[1]) ===
          //   SF_mask = sar_sign[diff[3]]
          //   Y       = a_sign XOR diff_sign = SF_mask XOR cmp_mask_buf[2]
          //   OF_mask = (a_sign XOR b_sign) AND Y = cmp_mask_buf[3] AND Y
          //   t       = SF_mask XOR OF_mask
          // Predicates:
          //   L  : mask = t
          //   GE : mask = NOT t
          //   LE : mask = t OR ZF_mask
          //   G  : mask = NOT (t OR ZF_mask)

          // SF_mask = sar_sign[srcdst[3]]  (srcdst still holds diff bytes).
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
              .addReg(Mov::EBP).addImm(Addr->SrcDstDisp + 3);
          emitUnaryByteLookup(MBB, Insert, DL, TII, *Addr, Mov::DL,
                              "__mov_sar_sign_byte", Mov::DL);
          // Stash SF_mask to cmp_mask_buf[0] (scratch; final mask later
          // overwrites it).
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
              .addReg(Mov::EBP).addImm(*Addr->CmpMaskBufDisp).addReg(Mov::DL);

          // Y = SF_mask XOR a_sign (cmp_mask_buf[2]).
          emitIdxZero(MBB, Insert, DL, TII, *Addr);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
              .addReg(Mov::EBP).addImm(Addr->IdxDisp + 1).addReg(Mov::DL);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
              .addReg(Mov::EBP).addImm(*Addr->CmpMaskBufDisp + 2);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
              .addReg(Mov::EBP).addImm(Addr->IdxDisp).addReg(Mov::DL);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
              .addReg(Mov::EBP).addImm(Addr->IdxDisp);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
              .addExternalSymbol("__mov_xor8_table").addReg(Mov::ECX);
          // DL = Y.

          // OF_mask = X AND Y  (X at cmp_mask_buf[3]).
          emitIdxZero(MBB, Insert, DL, TII, *Addr);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
              .addReg(Mov::EBP).addImm(Addr->IdxDisp + 1).addReg(Mov::DL);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
              .addReg(Mov::EBP).addImm(*Addr->CmpMaskBufDisp + 3);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
              .addReg(Mov::EBP).addImm(Addr->IdxDisp).addReg(Mov::DL);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
              .addReg(Mov::EBP).addImm(Addr->IdxDisp);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
              .addExternalSymbol("__mov_and8_table").addReg(Mov::ECX);
          // DL = OF_mask.

          // t = SF_mask XOR OF_mask  (SF_mask at cmp_mask_buf[0]).
          emitIdxZero(MBB, Insert, DL, TII, *Addr);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
              .addReg(Mov::EBP).addImm(Addr->IdxDisp + 1).addReg(Mov::DL);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
              .addReg(Mov::EBP).addImm(*Addr->CmpMaskBufDisp);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
              .addReg(Mov::EBP).addImm(Addr->IdxDisp).addReg(Mov::DL);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
              .addReg(Mov::EBP).addImm(Addr->IdxDisp);
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
              .addExternalSymbol("__mov_xor8_table").addReg(Mov::ECX);
          // DL = t = SF XOR OF.

          if (IsLE || IsG) {
            // OR with ZF_mask (cmp_mask_buf[1]).
            emitIdxZero(MBB, Insert, DL, TII, *Addr);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
                .addReg(Mov::EBP).addImm(Addr->IdxDisp + 1).addReg(Mov::DL);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
                .addReg(Mov::EBP).addImm(*Addr->CmpMaskBufDisp + 1);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
                .addReg(Mov::EBP).addImm(Addr->IdxDisp).addReg(Mov::DL);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
                .addReg(Mov::EBP).addImm(Addr->IdxDisp);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
                .addExternalSymbol("__mov_or8_table").addReg(Mov::ECX);
          }
          if (IsGE || IsG) {
            // Invert: XOR with 0xFF.
            emitIdxZero(MBB, Insert, DL, TII, *Addr);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
                .addReg(Mov::EBP).addImm(Addr->IdxDisp + 1).addReg(Mov::DL);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mi))
                .addReg(Mov::EBP).addImm(Addr->IdxDisp).addImm(0xFF);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
                .addReg(Mov::EBP).addImm(Addr->IdxDisp);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
                .addExternalSymbol("__mov_xor8_table").addReg(Mov::ECX);
          }
          // DL = final signed predicate mask.
        } else {
          // === Unsigned flag math (CF; ZF already at cmp_mask_buf[1]) ===
          // Predicates:
          //   B  : mask = CF_mask
          //   AE : mask = NOT CF_mask
          //   BE : mask = CF_mask OR ZF_mask
          //   A  : mask = NOT (CF_mask OR ZF_mask)

          // Load CF byte from cmp_mask_buf[0] (stashed at end of Phase 1'),
          // convert to CF_mask via select_mask_table. CF byte is 0 or 1.
          BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
              .addReg(Mov::EBP).addImm(*Addr->CmpMaskBufDisp);
          emitUnaryByteLookup(MBB, Insert, DL, TII, *Addr, Mov::DL,
                              "__mov_select_mask_table", Mov::DL);
          // DL = CF_mask. cmp_mask_buf[1] = ZF_mask.

          if (IsAE) {
            // mask = NOT CF_mask : XOR with 0xFF.
            emitIdxZero(MBB, Insert, DL, TII, *Addr);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
                .addReg(Mov::EBP).addImm(Addr->IdxDisp + 1).addReg(Mov::DL);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mi))
                .addReg(Mov::EBP).addImm(Addr->IdxDisp).addImm(0xFF);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
                .addReg(Mov::EBP).addImm(Addr->IdxDisp);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
                .addExternalSymbol("__mov_xor8_table").addReg(Mov::ECX);
          } else if (IsBE || IsA) {
            // mask = CF_mask OR ZF_mask  (BE), then XOR 0xFF for A.
            emitIdxZero(MBB, Insert, DL, TII, *Addr);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
                .addReg(Mov::EBP).addImm(Addr->IdxDisp + 1).addReg(Mov::DL);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
                .addReg(Mov::EBP).addImm(*Addr->CmpMaskBufDisp + 1);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
                .addReg(Mov::EBP).addImm(Addr->IdxDisp).addReg(Mov::DL);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
                .addReg(Mov::EBP).addImm(Addr->IdxDisp);
            BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
                .addExternalSymbol("__mov_or8_table").addReg(Mov::ECX);
            if (IsA) {
              // Invert the OR result via XOR 0xFF.
              emitIdxZero(MBB, Insert, DL, TII, *Addr);
              BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
                  .addReg(Mov::EBP).addImm(Addr->IdxDisp + 1).addReg(Mov::DL);
              BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mi))
                  .addReg(Mov::EBP).addImm(Addr->IdxDisp).addImm(0xFF);
              BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
                  .addReg(Mov::EBP).addImm(Addr->IdxDisp);
              BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
                  .addExternalSymbol("__mov_xor8_table").addReg(Mov::ECX);
            }
          }
          // IsB: DL already holds CF_mask — that's the final mask.
        }
        }
        // Stash mask at cmp_mask_buf[0]
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
            .addReg(Mov::EBP).addImm(*Addr->CmpMaskBufDisp).addReg(Mov::DL);
        // Compute inv_mask = mask XOR 0xFF, stash at cmp_mask_buf[1]
        emitIdxZero(MBB, Insert, DL, TII, *Addr);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mr))
            .addReg(Mov::EBP).addImm(Addr->IdxDisp + 1).addReg(Mov::DL);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mi))
            .addReg(Mov::EBP).addImm(Addr->IdxDisp).addImm(0xFF);
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
        //
        // opt 6 — Phase 5 idx-zero hoist: idx[2..3]=0 is the only
        // invariant the byte-table lookups depend on (the and8 /
        // or8 tables are indexed by `a*256 + b`, so the top two
        // bytes of `idx` MUST stay zero). idx[0] and idx[1] get
        // overwritten by every iteration's pack-and-store before
        // the table read. Phase 3 above already emitted at least
        // one emitIdxZero so idx[2..3] start at zero entering this
        // loop, and no MI in the loop writes those bytes — they
        // ride through all 4 iterations and the
        // emitOrByteAndStore tail (which also touches only idx[0]
        // and idx[1]). So the 8 per-iteration `emitIdxZero` calls
        // the previous shape emitted are 100% redundant; drop them.
        for (unsigned i = 0; i < 4; ++i) {
          const int64_t NextPCByteDisp = NextPCDisp + static_cast<int64_t>(i);

          // (~mask & F[i]) → DL; stash to next_pc[i].
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
  // Stage 7d1 — `pop ebp; ret` (function epilogue tail) → mov-only
  // sequence ending in `jmp dword ptr [__mov_return_addr_slot]`.
  //
  // Why this pair (not just RET): at the moment `ret` would execute,
  // POP32r EBP has already restored caller's EBP, so [EBP + scratch]
  // / [EBP + next_pc_disp] all point into the caller's frame. Any
  // mov-only rewrite of RET in isolation can't reach our scratch.
  // Splitting the pair across two MachineInstrs is also fragile
  // because POP32r EBP itself is what destroys our EBP base.
  //
  // The rewrite handles them together. At entry the state is:
  //   ESP == EBP   (the preceding `mov esp, ebp` in emitEpilogue set this)
  //   [ESP + 0]    = caller's EBP (saved by prologue's `push ebp`)
  //   [ESP + 4]    = our return address (pushed by `call`)
  //
  // Emitted sequence (every line is mov / movzx-style; the only
  // non-mov is the trailing JMP32m, which is the dispatcher-style
  // indirect jump we accept as mov-equivalent):
  //
  //   mov  edx, [esp + 4]                        ; edx = RA
  //   mov  ecx, __mov_return_addr_slot           ; ecx = &slot
  //   mov  [ecx], edx                            ; *slot = RA
  //   ; ESP += 8 via the 7a byte ADD chain (uses [ebp + scratch],
  //   ; EBP still ours throughout). The chain saves/restores ECX
  //   ; around itself, so ECX = &slot survives.
  //   <byte-chain ADD ESP, 8 over [ebp + SaveEcx/SaveEdx/SrcDst/Idx]>
  //   mov  ebp, [esp - 8]                        ; caller's EBP (was at
  //                                              ; [old_esp+0] = [new_esp-8])
  //   jmp  dword ptr [ecx]                       ; indirect jump via slot
  //
  // After this the MBB ends with JMP32m (isBarrier=1), no MBB
  // successor — matches the original RET-terminated shape. The
  // implicit EAX use that RET had is preserved on the new JMP32m
  // so MachineVerifier keeps EAX live to function exit.
  //
  // Recursion: `__mov_return_addr_slot` is shared across all
  // functions, but each `ret` writes-then-reads atomically before
  // the next nested call can return. No re-entrance from signal
  // handlers in the bootstrap runtime.
  bool legalizeRetEpilogueTail(MachineFunction &MF,
                               const TargetInstrInfo &TII) const {
    const std::optional<EbpAddr> Addr = resolveScratchAddrs(MF);
    if (!Addr)
      return false;

    bool Changed = false;
    for (MachineBasicBlock &MBB : MF) {
      auto It = MBB.begin();
      while (It != MBB.end()) {
        if (It->getOpcode() != Mov::POP32r ||
            It->getOperand(0).getReg() != Mov::EBP) {
          ++It;
          continue;
        }
        // Next non-debug MI must be RET.
        auto Next = std::next(It);
        while (Next != MBB.end() && Next->isDebugInstr())
          ++Next;
        if (Next == MBB.end() || Next->getOpcode() != Mov::RET) {
          ++It;
          continue;
        }

        MachineInstr &PopMI = *It;
        MachineInstr &RetMI = *Next;
        const DebugLoc DL = PopMI.getDebugLoc();
        auto Insert = MachineBasicBlock::iterator(&PopMI);

        // Step 1: stash RA in __mov_return_addr_slot.
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::EDX)
            .addReg(Mov::ESP).addImm(4);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32ri), Mov::ECX)
            .addExternalSymbol("__mov_return_addr_slot");
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
            .addReg(Mov::ECX).addImm(0).addReg(Mov::EDX);

        // Step 2: byte-chain ADD ESP, 8.
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
            .addReg(Mov::EBP).addImm(Addr->SaveEcxDisp).addReg(Mov::ECX, RegState::Undef);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
            .addReg(Mov::EBP).addImm(Addr->SaveEdxDisp).addReg(Mov::EDX, RegState::Undef);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
            .addReg(Mov::EBP).addImm(Addr->SrcDstDisp).addReg(Mov::ESP);

        const uint32_t K = 8;
        const std::array<uint8_t, 4> KBytes = {
            static_cast<uint8_t>(K & 0xFFu),
            static_cast<uint8_t>((K >> 8) & 0xFFu),
            static_cast<uint8_t>((K >> 16) & 0xFFu),
            static_cast<uint8_t>((K >> 24) & 0xFFu),
        };
        for (unsigned ByteIdx = 0; ByteIdx < 4; ++ByteIdx)
          emitByteStageAdd(MBB, Insert, DL, TII, *Addr, ByteIdx,
                           ByteSource::fromImm(KBytes[ByteIdx]));

        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
            .addReg(Mov::EBP).addImm(Addr->SaveEcxDisp);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::EDX)
            .addReg(Mov::EBP).addImm(Addr->SaveEdxDisp);
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ESP)
            .addReg(Mov::EBP).addImm(Addr->SrcDstDisp);

        // Step 3: restore caller's EBP and jmp via slot.
        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::EBP)
            .addReg(Mov::ESP).addImm(-8);
        // Preserve the original RET's implicit operands (e.g. `$eax`
        // for i32-returning functions, `$edx`+`$eax` for multi-value
        // returns) on the dispatcher jump so MachineVerifier sees the
        // return value as live through to function exit. Void / sret
        // returns have no implicit operands on the RET, so this
        // correctly omits the (otherwise undefined) EAX use.
        auto JmpMI = BuildMI(MBB, Insert, DL, TII.get(Mov::JMP32m))
            .addReg(Mov::ECX).addImm(0);
        for (const MachineOperand &MO : RetMI.implicit_operands())
          JmpMI.add(MO);

        // Erase pop ebp + ret. Resume scan past the original ret.
        auto NextOuter = std::next(MachineBasicBlock::iterator(&RetMI));
        PopMI.eraseFromParent();
        RetMI.eraseFromParent();
        It = NextOuter;
        Changed = true;
      }
    }
    return Changed;
  }

  // Stage 7d2 — `push ebp` at the head of the function prologue →
  // mov-only sequence. Has to be hand-rolled (not via the EBP-scratch
  // byte-chain helpers) because at this MI EBP still holds the
  // *caller's* frame pointer: `[ebp + scratch_disp]` would resolve
  // into the caller's frame, not our scratch.
  //
  // Earlier drafts used ESP-relative slots below the current ESP,
  // but writing 12-16 bytes below ESP can fault on a stack guard
  // page when the caller enters with ESP close to a page boundary
  // (codex P1 review on 7d2). Instead we use the `.bss` slot
  // `__mov_esp_dec_scratch` (16 bytes, always mapped) as the
  // scratch base, loaded into EAX:
  //
  //   __mov_esp_dec_scratch + 0   srcdst (ESP value being decremented)
  //   __mov_esp_dec_scratch + 4   idx (4-byte sub8-table index pack)
  //
  // Sequence:
  //   mov  [esp - 4], ebp                       ; save ebp_caller at
  //                                              ; standard push slot
  //   mov  eax, offset __mov_esp_dec_scratch    ; eax = &global scratch
  //   mov  [eax + 0], esp                        ; srcdst = esp_caller
  //   <4 byte stages SUB by 4 via [eax + 0..7], ECX/EDX/CL/DL transient>
  //   mov  esp, [eax + 0]                        ; esp = esp_caller - 4
  //
  // After the rewrite, the original `mov ebp, esp` (already mov,
  // untouched by this pass) sets EBP to esp_caller - 4 so subsequent
  // EBP-relative addressing — including stage 7d0's prologue SUB
  // legalize for `sub esp, K` — sees our frame.
  //
  // EAX is caller-saved per cdecl, undefined at function entry, so
  // freely clobbered here without needing save/restore.
  bool legalizePushEbpPrologue(MachineFunction &MF,
                               const TargetInstrInfo &TII) const {
    if (MF.empty())
      return false;
    MachineBasicBlock &EntryMBB = MF.front();
    auto It = EntryMBB.begin();
    while (It != EntryMBB.end() && It->isDebugInstr())
      ++It;
    if (It == EntryMBB.end())
      return false;
    if (It->getOpcode() != Mov::PUSH32r ||
        It->getOperand(0).getReg() != Mov::EBP)
      return false;

    MachineInstr &PushMI = *It;
    const DebugLoc DL = PushMI.getDebugLoc();
    auto Insert = MachineBasicBlock::iterator(&PushMI);

    constexpr int64_t SavedEbpDisp = -4;
    constexpr int64_t SrcDstBase = 0;
    constexpr int64_t IdxBase = 4;
    constexpr uint32_t K = 4;

    // Step 1 — save ebp_caller at the standard push slot. Same single
    // 4-byte write the original `push ebp` does, so it doesn't widen
    // the guard-page exposure.
    BuildMI(EntryMBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::ESP).addImm(SavedEbpDisp).addReg(Mov::EBP);

    // Step 2 — point EAX at the global scratch and seed srcdst = ESP.
    BuildMI(EntryMBB, Insert, DL, TII.get(Mov::MOV32ri), Mov::EAX)
        .addExternalSymbol("__mov_esp_dec_scratch");
    BuildMI(EntryMBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EAX).addImm(SrcDstBase).addReg(Mov::ESP);

    // Step 3 — 4 byte stages of SUB by K=4 using the global scratch.
    //
    // ECX/EDX/CL/DL are all caller-saved per cdecl, free here.
    // CL carries the borrow_out across stages; the first stage sees
    // borrow_in = 0 (zeroed via the idx MOV32mi 0 init), subsequent
    // stages overwrite idx[2] with CL. EAX stays pinned to the
    // scratch base throughout.
    for (unsigned i = 0; i < 4; ++i) {
      // mov [eax + idx + 0..3], 0   ; zero the 4 idx bytes
      BuildMI(EntryMBB, Insert, DL, TII.get(Mov::MOV32mi))
          .addReg(Mov::EAX).addImm(IdxBase).addImm(0);

      // mov dl, [eax + srcdst + i]
      BuildMI(EntryMBB, Insert, DL, TII.get(Mov::MOV8rm), Mov::DL)
          .addReg(Mov::EAX).addImm(SrcDstBase + static_cast<int64_t>(i));
      // mov [eax + idx + 1], dl     ; idx[1] = a_byte
      BuildMI(EntryMBB, Insert, DL, TII.get(Mov::MOV8mr))
          .addReg(Mov::EAX).addImm(IdxBase + 1).addReg(Mov::DL);

      // opt 4 — store K_byte_i directly to idx[0] via MOV8mi
      // (skipping if it's 0, since the MOV32mi above already
      // zeroed idx[0..3]).
      const uint8_t KByte = static_cast<uint8_t>((K >> (8u * i)) & 0xFFu);
      if (KByte != 0) {
        BuildMI(EntryMBB, Insert, DL, TII.get(Mov::MOV8mi))
            .addReg(Mov::EAX).addImm(IdxBase).addImm(KByte);
      }

      // if i > 0: mov [eax + idx + 2], cl  ; idx[2] = borrow_in
      if (i > 0) {
        BuildMI(EntryMBB, Insert, DL, TII.get(Mov::MOV8mr))
            .addReg(Mov::EAX).addImm(IdxBase + 2).addReg(Mov::CL);
      }

      // mov ecx, [eax + idx]
      BuildMI(EntryMBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ECX)
          .addReg(Mov::EAX).addImm(IdxBase);
      // mov dl, [__mov_sub8_diff_table + ecx]
      BuildMI(EntryMBB, Insert, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
          .addExternalSymbol("__mov_sub8_diff_table").addReg(Mov::ECX);
      // mov [eax + srcdst + i], dl
      BuildMI(EntryMBB, Insert, DL, TII.get(Mov::MOV8mr))
          .addReg(Mov::EAX).addImm(SrcDstBase + static_cast<int64_t>(i))
          .addReg(Mov::DL);
      // if i < 3: mov cl, [__mov_sub8_borrow_table + ecx]  ; borrow_out
      if (i < 3) {
        BuildMI(EntryMBB, Insert, DL, TII.get(Mov::MOV8rm_idx), Mov::CL)
            .addExternalSymbol("__mov_sub8_borrow_table").addReg(Mov::ECX);
      }
    }

    // Step 4 — load the decremented ESP value back into ESP.
    BuildMI(EntryMBB, Insert, DL, TII.get(Mov::MOV32rm), Mov::ESP)
        .addReg(Mov::EAX).addImm(SrcDstBase);

    PushMI.eraseFromParent();
    return true;
  }

  // Stage 7d3 — each `CALL32d` is rewritten into a mov-only sequence
  // that stores the return-address label at [esp - 4], decrements
  // ESP by 4 via __mov_esp_dec_scratch byte chain, and falls into a
  // direct `JMP32d_CALL <callee>` terminator. The MBB is split
  // immediately after the CALL so the continuation gets its own
  // symbol — that label is the return target the callee's 7d1
  // `pop ebp + ret` will jump back to via __mov_return_addr_slot.
  //
  // CFG: the original MBB ending in CALL now ends in JMP32d_CALL with
  // its continuation MBB as the sole successor. JMP32d_CALL is
  // marked `isBarrier=1` (no fallthrough) — the successor edge is
  // purely a "call continuation" annotation, mirroring how 7c1's
  // dispatcher gets indirect successors. The callee's regmask +
  // implicit caller-clobber operands from CALL32d are transferred
  // to the new JMP32d_CALL so late liveness analysis still sees
  // the call's clobber semantics (critical for `call_live_across`
  // shapes).
  bool legalizeCallSites(MachineFunction &MF,
                         const TargetInstrInfo &TII) const {
    bool Changed = false;
    auto BBIt = MF.begin();
    while (BBIt != MF.end()) {
      MachineBasicBlock &MBB = *BBIt;
      // Walk the MBB looking for the first CALL32d. Each rewrite
      // splits the MBB and the continuation goes into ContMBB —
      // we keep BBIt on this MBB position so the very next loop
      // iteration descends into ContMBB and picks up any further
      // CALL32d sites in the same logical block (codex P2).
      MachineInstr *CallMI = nullptr;
      for (MachineInstr &MI : MBB) {
        if (MI.getOpcode() == Mov::CALL32d) {
          CallMI = &MI;
          break;
        }
      }
      if (!CallMI) {
        ++BBIt;
        continue;
      }

      MachineFunction *MFp = MBB.getParent();
      const DebugLoc DL = CallMI->getDebugLoc();
      MachineOperand CalleeOp = CallMI->getOperand(0);

      // Split: continuation MBB owns everything after the CALL
      // (exclusive). The split point is the iterator just past the
      // CALL MI. splitAt transfers MIs and updates successor edges.
      MachineBasicBlock *ContMBB = MFp->CreateMachineBasicBlock(
          MBB.getBasicBlock());
      MFp->insert(std::next(MachineFunction::iterator(&MBB)), ContMBB);
      // Force the AsmPrinter to emit ContMBB's label even though it
      // looks like a fallthrough — the MOV32mi above stores
      // `offset <ContMBB symbol>` as the return address, and the
      // callee's 7d1 epilogue jumps to that symbol via
      // `__mov_return_addr_slot`, so the symbol must exist in
      // the linked ELF.
      ContMBB->setLabelMustBeEmitted();

      // Move everything past the CALL into the continuation MBB.
      auto SplitIt = std::next(MachineBasicBlock::iterator(CallMI));
      ContMBB->splice(ContMBB->end(), &MBB, SplitIt, MBB.end());

      // Transfer the original MBB's existing successors to ContMBB
      // (the CALL itself was not a terminator in the LLVM CFG, so
      // the original MBB's successors flow from whatever came after
      // CALL — which is now in ContMBB).
      ContMBB->transferSuccessors(&MBB);

      // The pre-CALL MBB now ends in our JMP32d_CALL with ContMBB
      // as the sole successor (the call continuation edge).
      MBB.addSuccessor(ContMBB);

      // Live-ins for ContMBB get recomputed globally at the end of
      // MovOnlyLegalize via `fullyRecomputeLiveIns` (see the bottom
      // of runOnMachineFunction). Setting them here too would just
      // be redundant — and the prior hand-rolled set
      // {EAX, ECX, EDX, ESP, EBP, callee-saved-as-discovered}
      // wasn't sufficient for IR-level MBBs whose live-ins also
      // need refreshing after the byte-chain rewrites land.

      // opt 5 — fold the preceding ADJCALLSTACKDOWN's `sub esp, N`
      // (post-PEI, that's the SUB32ri ESP, N right before the arg
      // store chain) into THIS rewrite's byte chain. The combined
      // chain decrements ESP by N+4 in one shot instead of doing
      // ADJCALLSTACKDOWN's chain + 7d3's chain separately. Saves one
      // full ~30-mov byte chain per call site whose ADJCALLSTACKDOWN
      // is non-zero (i.e. every call with at least one arg).
      //
      // Scan backward from the CALL collecting arg stores
      // (MOV32mr [esp+disp]) and the preceding SUB32ri ESP, N (if
      // any). We also tolerate intervening non-ESP-touching reg-def
      // MIs — Rust's codegen interleaves `mov eax, IMM` between an
      // arg value's computation and its `mov [esp+i], eax` store,
      // and clang sometimes does the same when an arg flows through
      // a virtual register that ended up on a different physreg
      // than the spill destination. Anything that *could* read or
      // write ESP (or write to memory at [esp + …]) breaks the
      // scan and aborts the fold.
      SmallVector<MachineInstr *, 8> ArgStores;
      MachineInstr *AdjSub = nullptr;
      auto MayTouchEsp = [&](const MachineInstr &MI) -> bool {
        // The reg-def-only patterns we're willing to skip: MOV32ri,
        // MOV32rr, MOV32rm (load from a non-ESP base into a non-ESP
        // dst). Anything that could touch ESP or write through ESP
        // is fatal to the fold.
        switch (MI.getOpcode()) {
        case Mov::MOV32ri:
        case Mov::MOV32rr:
        case Mov::MOV32rm:
          // Op 0 is the dst register (def).
          if (MI.getNumOperands() < 1 || !MI.getOperand(0).isReg())
            return true;
          if (MI.getOperand(0).getReg() == Mov::ESP)
            return true;
          // MOV32rr's src reg must not be ESP either (technically the
          // value of ESP being copied is fine, but folding past it
          // would change which ESP value the chain captures).
          if (MI.getOpcode() == Mov::MOV32rr &&
              MI.getNumOperands() >= 2 && MI.getOperand(1).isReg() &&
              MI.getOperand(1).getReg() == Mov::ESP)
            return true;
          // MOV32rm's base must not be ESP-via-frame for the same
          // reason (its load value could be the to-be-folded ESP).
          if (MI.getOpcode() == Mov::MOV32rm &&
              MI.getNumOperands() >= 2 && MI.getOperand(1).isReg() &&
              MI.getOperand(1).getReg() == Mov::ESP)
            return true;
          return false;
        default:
          return true;
        }
      };
      {
        auto Probe = MachineBasicBlock::iterator(CallMI);
        while (Probe != MBB.begin()) {
          --Probe;
          unsigned POp = Probe->getOpcode();
          if (POp == Mov::MOV32mr &&
              Probe->getOperand(0).isReg() &&
              Probe->getOperand(0).getReg() == Mov::ESP) {
            ArgStores.push_back(&*Probe);
            continue;
          }
          if (POp == Mov::SUB32ri &&
              Probe->getOperand(0).isReg() &&
              Probe->getOperand(0).getReg() == Mov::ESP &&
              Probe->getOperand(2).isImm()) {
            AdjSub = &*Probe;
            break;
          }
          if (MayTouchEsp(*Probe))
            break;
          // Reg-def-only MI that doesn't touch ESP — keep scanning.
        }
      }

      // opt-5 safety check (codex P1): the relocated byte chain
      // clobbers EAX/ECX/EDX. If any MI between (would-be) ChainPos
      // and CallMI reads one of those registers BEFORE it is
      // re-defined, that read would now pick up scratch garbage
      // instead of the original value. Walk the candidate fold
      // region forward, tracking which scratch regs are "fresh"
      // again. Bail out of the fold if we find a stale read.
      if (AdjSub) {
        auto IsScratch = [](Register R) {
          return R == Mov::EAX || R == Mov::ECX || R == Mov::EDX;
        };
        bool DefinedSinceChain[3] = {false, false, false};
        auto Idx = [](Register R) -> int {
          if (R == Mov::EAX) return 0;
          if (R == Mov::ECX) return 1;
          if (R == Mov::EDX) return 2;
          return -1;
        };
        bool Unsafe = false;
        for (auto It = std::next(MachineBasicBlock::iterator(AdjSub));
             It != MachineBasicBlock::iterator(CallMI); ++It) {
          // Check uses first — a same-MI def of the read reg counts
          // as a redefinition only for SUBSEQUENT MIs, not this one.
          for (const MachineOperand &Op : It->operands()) {
            if (!Op.isReg() || Op.isDef() || Op.isImplicit())
              continue;
            const Register R = Op.getReg();
            const int i = Idx(R);
            if (i >= 0 && !DefinedSinceChain[i]) {
              Unsafe = true;
              break;
            }
          }
          if (Unsafe)
            break;
          for (const MachineOperand &Op : It->operands()) {
            if (Op.isReg() && Op.isDef() && !Op.isImplicit()) {
              const int i = Idx(Op.getReg());
              if (i >= 0)
                DefinedSinceChain[i] = true;
            }
          }
          (void)IsScratch;
        }
        if (Unsafe)
          AdjSub = nullptr;  // abort fold; fall back to standalone K=4 chain
      }

      uint32_t ExtraK = 0;
      // ChainPos = where the combined byte chain should be inserted.
      // - With fold: just before the (now-erased) ADJCALLSTACKDOWN
      //   SUB, so the chain runs BEFORE the arg stores.
      // - Without fold: at the CALL itself.
      MachineBasicBlock::iterator ChainPos =
          MachineBasicBlock::iterator(CallMI);
      if (AdjSub) {
        ExtraK = static_cast<uint32_t>(AdjSub->getOperand(2).getImm());
        // Arg stores will execute with ESP already decremented by N+4
        // (instead of just N), so each [esp + disp] needs disp += 4.
        for (auto *MI : ArgStores) {
          MachineOperand &Disp = MI->getOperand(1);
          Disp.setImm(Disp.getImm() + 4);
        }
        ChainPos = std::next(MachineBasicBlock::iterator(AdjSub));
        AdjSub->eraseFromParent();
      }
      const uint32_t K = 4 + ExtraK;

      // Emit the rewrite. ChainPos is where the byte chain goes (= SUB
      // pos for fold, = CALL pos otherwise); RA-store + JMP32d_CALL
      // are always at CALL pos so they land after any arg stores.
      auto Insert = MachineBasicBlock::iterator(CallMI);

      constexpr int64_t SrcDstBase = 0;
      constexpr int64_t IdxBase = 4;

      // Step 1 — point EAX at the global scratch and seed srcdst = ESP.
      BuildMI(MBB, ChainPos, DL, TII.get(Mov::MOV32ri), Mov::EAX)
          .addExternalSymbol("__mov_esp_dec_scratch");
      BuildMI(MBB, ChainPos, DL, TII.get(Mov::MOV32mr))
          .addReg(Mov::EAX).addImm(SrcDstBase).addReg(Mov::ESP);

      // Step 2 — 4 byte stages of SUB by K=4+ExtraK.
      for (unsigned i = 0; i < 4; ++i) {
        BuildMI(MBB, ChainPos, DL, TII.get(Mov::MOV32mi))
            .addReg(Mov::EAX).addImm(IdxBase).addImm(0);

        BuildMI(MBB, ChainPos, DL, TII.get(Mov::MOV8rm), Mov::DL)
            .addReg(Mov::EAX).addImm(SrcDstBase + static_cast<int64_t>(i));
        BuildMI(MBB, ChainPos, DL, TII.get(Mov::MOV8mr))
            .addReg(Mov::EAX).addImm(IdxBase + 1).addReg(Mov::DL);

        // opt 4 — direct MOV8mi for K_byte (skip if 0, idx already
        // zeroed by the MOV32mi above).
        const uint8_t KByte =
            static_cast<uint8_t>((K >> (8u * i)) & 0xFFu);
        if (KByte != 0) {
          BuildMI(MBB, ChainPos, DL, TII.get(Mov::MOV8mi))
              .addReg(Mov::EAX).addImm(IdxBase).addImm(KByte);
        }

        if (i > 0) {
          BuildMI(MBB, ChainPos, DL, TII.get(Mov::MOV8mr))
              .addReg(Mov::EAX).addImm(IdxBase + 2).addReg(Mov::CL);
        }

        BuildMI(MBB, ChainPos, DL, TII.get(Mov::MOV32rm), Mov::ECX)
            .addReg(Mov::EAX).addImm(IdxBase);
        BuildMI(MBB, ChainPos, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
            .addExternalSymbol("__mov_sub8_diff_table").addReg(Mov::ECX);
        BuildMI(MBB, ChainPos, DL, TII.get(Mov::MOV8mr))
            .addReg(Mov::EAX).addImm(SrcDstBase + static_cast<int64_t>(i))
            .addReg(Mov::DL);
        if (i < 3) {
          BuildMI(MBB, ChainPos, DL, TII.get(Mov::MOV8rm_idx), Mov::CL)
              .addExternalSymbol("__mov_sub8_borrow_table")
              .addReg(Mov::ECX);
        }
      }

      // Step 3 — load decremented ESP back into ESP. After this ESP
      // points at the (eventual) RA slot, with the arg stores'
      // disp-adjusted writes still ahead in MBB order between
      // ChainPos and Insert.
      BuildMI(MBB, ChainPos, DL, TII.get(Mov::MOV32rm), Mov::ESP)
          .addReg(Mov::EAX).addImm(SrcDstBase);

      // Step 4 — store the return-address label at [esp + 0]. This
      // runs AFTER the arg stores so it lands at the final ESP
      // position. (In the non-fold K=4 case this is at the same
      // physical address as the previous "mov [esp - 4], ret_label"
      // pre-chain shape, since ESP has been decremented by 4.)
      BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mi))
          .addReg(Mov::ESP).addImm(0).addMBB(ContMBB);

      // Step 5 — emit JMP32d_CALL with the callee, carrying over the
      // regmask + implicit defs from the original CALL32d so late
      // liveness sees the same caller-saved clobbers.
      auto NewJmp = BuildMI(MBB, Insert, DL, TII.get(Mov::JMP32d_CALL));
      if (CalleeOp.isGlobal())
        NewJmp.addGlobalAddress(CalleeOp.getGlobal(), CalleeOp.getOffset(),
                                CalleeOp.getTargetFlags());
      else if (CalleeOp.isSymbol())
        NewJmp.addExternalSymbol(CalleeOp.getSymbolName(),
                                 CalleeOp.getTargetFlags());
      else if (CalleeOp.isMBB())
        NewJmp.addMBB(CalleeOp.getMBB(), CalleeOp.getTargetFlags());
      else
        report_fatal_error("CALL32d: unexpected callee operand kind");
      // Transfer remaining operands (regmask + implicit defs/uses).
      for (unsigned i = 1, e = CallMI->getNumOperands(); i < e; ++i)
        NewJmp.add(CallMI->getOperand(i));

      // Erase the original CALL32d.
      CallMI->eraseFromParent();
      Changed = true;

      // Advance BBIt to ContMBB so the next loop iteration scans
      // the continuation for any further CALL32d sites that lived
      // in the same original block (codex P2). Without this the
      // outer loop would skip ContMBB and only the first call in
      // each original block would be legalised.
      BBIt = MachineFunction::iterator(ContMBB);
    }
    return Changed;
  }

  // Stage 6b — expand bare FrameIndex materializations (LEA32r).
  //
  // After PEI, LEA32r looks like
  //     LEA32r <dst>, <base=EBP>, <disp=Imm>
  // (eliminateFrameIndex rewrote the FrameIndex operand into (EBP,
  // disp) the same way it does for load/store memory operands). We
  // expand each occurrence into
  //     MOV32rr <dst>, EBP
  //     ADD32ri <dst>, <dst>, disp
  // and erase the original LEA. The per-MI byte-chain loop below
  // then sees the ADD32ri and turns it into mov-only.
  //
  // Edge case: disp == 0 is rare (the FrameIndex would have to land
  // exactly on EBP) — we still emit the ADD32ri, and the per-MI
  // loop's opt-3 fold (`add reg, 0` → erase) drops it.
  //
  // Defensive bail: if a LEA32r somehow survived without being
  // resolved by eliminateFrameIndex (the base operand isn't a
  // physical register), leave it alone and rely on the verifier to
  // surface the bug — no mov-only rewrite is possible.
  bool legalizeLEA32rs(MachineFunction &MF,
                       const TargetInstrInfo &TII) const {
    bool Changed = false;
    for (MachineBasicBlock &MBB : MF) {
      for (MachineInstr &MI : llvm::make_early_inc_range(MBB)) {
        if (MI.getOpcode() != Mov::LEA32r)
          continue;
        assert(MI.getNumOperands() >= 3 && "LEA32r must have dst,base,disp");
        const MachineOperand &DstOp  = MI.getOperand(0);
        const MachineOperand &BaseOp = MI.getOperand(1);
        const MachineOperand &DispOp = MI.getOperand(2);
        if (!DstOp.isReg() || !BaseOp.isReg() || !DispOp.isImm())
          continue;
        const Register Dst  = DstOp.getReg();
        const Register Base = BaseOp.getReg();
        const int64_t Disp  = DispOp.getImm();
        const DebugLoc DL   = MI.getDebugLoc();
        auto Insert = MachineBasicBlock::iterator(&MI);

        BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32rr), Dst)
            .addReg(Base);
        // ADD32ri is 2-address (`$src1 = $dst`); post-RA we just
        // restate the dst register on both slots.
        BuildMI(MBB, Insert, DL, TII.get(Mov::ADD32ri), Dst)
            .addReg(Dst)
            .addImm(Disp);
        MI.eraseFromParent();
        Changed = true;
      }
    }
    return Changed;
  }

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
  //
  // ri zero-byte fast path: when BSrc is a compile-time immediate of
  // value 0, both the `mov dl, 0` and the `mov [idx + 0], dl` are
  // redundant — emitIdxZero already cleared idx[0] to 0, so the
  // store would only re-write the same value. Skipping the pair
  // saves 2 movs per zero-byte stage; for the common `add reg, 1`
  // shape (byte 0 = 1, bytes 1/2/3 = 0) that's 6 movs / ADD32ri site.
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

    // Zero-byte fast path for ri-form: idx[0] is already 0 from
    // emitIdxZero, so no write needed.
    if (BSrc.K == ByteSource::Kind::Imm && BSrc.Imm == 0)
      return;

    // Load b_byte and store to idx[0]:
    if (BSrc.K == ByteSource::Kind::Imm) {
      // opt 4 — single MOV8mi (mem-imm 8) instead of the
      // `mov dl, IMM; mov [idx+0], dl` pair. Saves 1 mov per
      // non-zero immediate K_byte slice (= 1 mov per ADD/SUB/AND/
      // OR/XOR ri site with a non-zero high byte). Zero K_byte
      // was already short-circuited by the early return above.
      BuildMI(MBB, I, DL, TII.get(Mov::MOV8mi))
          .addReg(Mov::EBP)
          .addImm(A.IdxDisp)
          .addImm(BSrc.Imm);
    } else {
      // mov dl, byte ptr [rhs_buf + i] ; rr-form RHS spill byte
      BuildMI(MBB, I, DL, TII.get(Mov::MOV8rm), Mov::DL)
          .addReg(Mov::EBP)
          .addImm(BSrc.MemDisp + static_cast<int64_t>(ByteIdx));
      // mov byte ptr [idx + 0], dl
      BuildMI(MBB, I, DL, TII.get(Mov::MOV8mr))
          .addReg(Mov::EBP)
          .addImm(A.IdxDisp)
          .addReg(Mov::DL);
    }
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

  // SUB per-byte stage — same shape as emitByteStageAdd but indexes
  // __mov_sub8_{diff,borrow}_table instead. CL holds the borrow-in /
  // borrow-out chain across the four bytes. Used by stage 7d0
  // legalizeSUB32ri to lower `sub reg, K` into a mov-only sequence
  // (the same byte SUB chain the stage 7c3 CMP+Jcc rewrite uses
  // against a memory operand, but here writing the diff back into
  // srcdst directly so `mov DST32, [srcdst]` at the end loads the
  // 32-bit result).
  static void emitByteStageSub(MachineBasicBlock &MBB,
                               MachineBasicBlock::iterator I,
                               const DebugLoc &DL,
                               const TargetInstrInfo &TII, const EbpAddr &A,
                               unsigned ByteIdx, ByteSource BSrc) {
    emitIdxZero(MBB, I, DL, TII, A);
    if (ByteIdx > 0) {
      // mov byte ptr [idx + 2], cl   ; borrow-in (CL holds borrow_out
      // from previous stage's sub8_borrow lookup)
      BuildMI(MBB, I, DL, TII.get(Mov::MOV8mr))
          .addReg(Mov::EBP)
          .addImm(A.IdxDisp + 2)
          .addReg(Mov::CL);
    }
    emitIdxPackAB(MBB, I, DL, TII, A, ByteIdx, BSrc);
    emitTableLookupAndStore(MBB, I, DL, TII, A, ByteIdx,
                            "__mov_sub8_diff_table");
    if (ByteIdx < 3) {
      // mov cl, byte ptr [sub8_borrow_table + ecx]  ; borrow-out
      BuildMI(MBB, I, DL, TII.get(Mov::MOV8rm_idx), Mov::CL)
          .addExternalSymbol("__mov_sub8_borrow_table")
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
        .addReg(Mov::ECX, RegState::Undef);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP)
        .addImm(Addr->SaveEdxDisp)
        .addReg(Mov::EDX, RegState::Undef);
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

  // Stage 7d0 — lower `SUB32ri DST32, DST32, IMM32` into a mov-only
  // byte SUB chain. Same prologue/epilogue shape as legalizeADD32ri;
  // the per-byte stage reads __mov_sub8_diff_table for the difference
  // and __mov_sub8_borrow_table for the borrow-out into CL.
  //
  // The most common SUB32ri site at this stage is the prologue
  // `sub esp, K` that FrameLowering::emitPrologue emits after
  // `mov ebp, esp`. EBP is valid at that point, so the byte-chain
  // scratch reads/writes at [EBP + scratch_disp] resolve correctly.
  //
  // Stack-frame ordering hazard: between this rewrite's first scratch
  // write and the final `mov esp, [srcdst]`, ESP still points to where
  // it did before the SUB. The scratch writes land below ESP briefly.
  // For small frames (< one page) those writes stay on the same memory
  // page as EBP/ESP, so no guard-page fault. For large frames the
  // most-negative scratch offset can cross a page boundary into an
  // unmapped guard page, which would fault before ESP has been moved.
  // The kPrologueScratchPageBudget guard below bails out of the
  // rewrite when that's the case — the original SUB32ri ESP stays
  // un-legalized (so `sub` remains in `.text`) until a later 7d
  // stage adds explicit stack probing.
  static constexpr int64_t kPrologueScratchPageBudget = 4000;

  bool legalizeSUB32ri(MachineInstr &MI, MachineBasicBlock &MBB,
                       const TargetInstrInfo &TII) const {
    const MachineFunction &MF = *MBB.getParent();
    const std::optional<EbpAddr> Addr = resolveScratchAddrs(MF);
    if (!Addr)
      return false;

    assert(MI.getOperand(0).isReg() && "SUB32ri op 0 must be reg");
    assert(MI.getOperand(2).isImm() && "SUB32ri op 2 must be imm");
    const Register Dst = MI.getOperand(0).getReg();

    // Guard: when rewriting `sub esp, K` (the prologue SUB), refuse
    // the rewrite if any scratch slot we'd touch sits more than
    // kPrologueScratchPageBudget bytes below EBP. The byte-chain
    // emits its first store before ESP has moved, and a write to
    // [EBP + scratch_disp] beyond a page boundary would fault on
    // an unmapped guard page. Non-ESP SUB32ri is unaffected since
    // it doesn't reorder the stack pointer's visible value.
    if (Dst == Mov::ESP) {
      auto FarBelowEbp = [&](int64_t Disp) {
        return Disp < -kPrologueScratchPageBudget;
      };
      if (FarBelowEbp(Addr->SaveEcxDisp) ||
          FarBelowEbp(Addr->SaveEdxDisp) ||
          FarBelowEbp(Addr->SrcDstDisp) ||
          FarBelowEbp(Addr->IdxDisp))
        return false;
    }
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
    // last so it captures its original value.
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP)
        .addImm(Addr->SaveEcxDisp)
        .addReg(Mov::ECX, RegState::Undef);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP)
        .addImm(Addr->SaveEdxDisp)
        .addReg(Mov::EDX, RegState::Undef);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP)
        .addImm(Addr->SrcDstDisp)
        .addReg(Dst);

    // CHAIN — four per-byte SUB stages. CL holds borrow_in / borrow_out.
    for (unsigned ByteIdx = 0; ByteIdx < 4; ++ByteIdx)
      emitByteStageSub(MBB, Insert, DL, TII, *Addr, ByteIdx,
                       ByteSource::fromImm(ImmBytes[ByteIdx]));

    // EPILOGUE — restore parent regs, then load DST32 from srcdst.
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
        .addReg(Mov::ECX, RegState::Undef);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP)
        .addImm(Addr->SaveEdxDisp)
        .addReg(Mov::EDX, RegState::Undef);
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
        .addReg(Mov::EBP).addImm(Addr->SaveEcxDisp).addReg(Mov::ECX, RegState::Undef);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP).addImm(Addr->SaveEdxDisp).addReg(Mov::EDX, RegState::Undef);
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
        .addReg(Mov::EBP).addImm(Addr->SaveEcxDisp).addReg(Mov::ECX, RegState::Undef);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP).addImm(Addr->SaveEdxDisp).addReg(Mov::EDX, RegState::Undef);
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
        .addReg(Mov::EBP).addImm(Addr->SaveEcxDisp).addReg(Mov::ECX, RegState::Undef);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP).addImm(Addr->SaveEdxDisp).addReg(Mov::EDX, RegState::Undef);
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
        .addReg(Mov::EBP).addImm(Addr->SaveEcxDisp).addReg(Mov::ECX, RegState::Undef);
    BuildMI(MBB, Insert, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP).addImm(Addr->SaveEdxDisp).addReg(Mov::EDX, RegState::Undef);
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
      BuildMI(MBB, Insert, DL, TII.get(Mov::MOV8mi))
          .addReg(Mov::EBP).addImm(Addr->IdxDisp).addImm(0xFF);
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
