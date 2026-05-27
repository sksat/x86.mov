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
    for (MachineBasicBlock &MBB : MF) {
      for (MachineInstr &MI : llvm::make_early_inc_range(MBB)) {
        switch (MI.getOpcode()) {
        case Mov::ADD32ri:
          Changed |= legalizeADD32ri(MI, MBB, TII);
          break;
        case Mov::ADD32rr:
          // Stage 7a1 only lands ADD32ri. ADD32rr needs an extra
          // 4-byte spill slot for the RHS register and a second
          // byte-extract path, both small but big enough to keep out
          // of the first commit. Falls through to no-op for now —
          // the existing 39 execution fixtures that use ADD32rr keep
          // hitting the original `add reg, reg` instruction.
          break;
        // SUB/AND/OR/XOR rr+ri, SHL/SHR/SAR ri/rCL, CMP+Jcc, CALL32d
        // + CALLSEQ, RET, and the prologue/epilogue PUSH/POP/SUB/MOV
        // sequence light up across stages 7b → 7d.
        default:
          break;
        }
      }
    }
    return Changed;
  }

private:
  // Address triple for `[EBP + Disp]`. Built once per legalize site
  // and reused for every BuildMI in the byte chain.
  struct EbpAddr {
    int64_t SaveEcxDisp;
    int64_t SaveEdxDisp;
    int64_t SrcDstDisp;
    int64_t IdxDisp;
  };

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

  // Look up the EBP-relative displacement for the four pre-PEI-reserved
  // scratch slots a stage-7a1 rewrite needs. Returns `std::nullopt` if
  // any slot is missing (i.e. the FrameLowering scan didn't see an
  // ADD32 in this function and skipped reservation — legalize must
  // bail in that case).
  //
  // The four slots are independent FIs, and MFI.getObjectOffset
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
    return EbpAddr{MFI.getObjectOffset(FI_Ecx), MFI.getObjectOffset(FI_Edx),
                   MFI.getObjectOffset(FI_Sd), MFI.getObjectOffset(FI_Ix)};
  }

  // Emit one per-byte stage of the carry chain. `ByteIdx` controls two
  // boundary conditions:
  //   - On byte 0 we don't load a carry-in from CL (there was no
  //     previous byte), so we skip both the `mov dl, cl` save and the
  //     `mov [idx + 2], dl` write. `mov [idx], ecx` (with ECX = 0)
  //     leaves idx[2] = 0 = correct cin for byte 0.
  //   - On byte 3 we don't need the carry-out for a following stage,
  //     so we skip the trailing `mov cl, [carry_table + ecx]` read.
  // The IMM operand is the per-byte slice of the original 32-bit
  // immediate (operand 2 of ADD32ri, masked to a u8 and shifted into
  // the right byte position).
  static void emitByteStage(MachineBasicBlock &MBB,
                            MachineBasicBlock::iterator I, const DebugLoc &DL,
                            const TargetInstrInfo &TII, const EbpAddr &A,
                            unsigned ByteIdx, uint8_t ImmByte) {
    const int64_t SrcByteDisp = A.SrcDstDisp + static_cast<int64_t>(ByteIdx);
    const int64_t IdxBaseDisp = A.IdxDisp;

    if (ByteIdx > 0) {
      // mov dl, cl              ; preserve carry across the upcoming ECX zero
      BuildMI(MBB, I, DL, TII.get(Mov::MOV8rr), Mov::DL).addReg(Mov::CL);
    }

    // mov ecx, 0               ; zero ECX so we can zero idx and rebuild it
    BuildMI(MBB, I, DL, TII.get(Mov::MOV32ri), Mov::ECX).addImm(0);

    // mov dword ptr [idx], ecx ; zero all four bytes of the idx slot
    BuildMI(MBB, I, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP)
        .addImm(IdxBaseDisp)
        .addReg(Mov::ECX);

    if (ByteIdx > 0) {
      // mov byte ptr [idx + 2], dl   ; carry-in byte (byte 0 of high word)
      BuildMI(MBB, I, DL, TII.get(Mov::MOV8mr))
          .addReg(Mov::EBP)
          .addImm(IdxBaseDisp + 2)
          .addReg(Mov::DL);
    }

    // mov dl, byte ptr [srcdst + i]
    BuildMI(MBB, I, DL, TII.get(Mov::MOV8rm), Mov::DL)
        .addReg(Mov::EBP)
        .addImm(SrcByteDisp);
    // mov byte ptr [idx + 1], dl     ; a_byte
    BuildMI(MBB, I, DL, TII.get(Mov::MOV8mr))
        .addReg(Mov::EBP)
        .addImm(IdxBaseDisp + 1)
        .addReg(Mov::DL);

    // mov dl, IMM8                   ; immediate slice (b_byte)
    BuildMI(MBB, I, DL, TII.get(Mov::MOV8ri), Mov::DL).addImm(ImmByte);
    // mov byte ptr [idx + 0], dl     ; b_byte
    BuildMI(MBB, I, DL, TII.get(Mov::MOV8mr))
        .addReg(Mov::EBP)
        .addImm(IdxBaseDisp)
        .addReg(Mov::DL);

    // mov ecx, dword ptr [idx]       ; load the packed index into ECX
    BuildMI(MBB, I, DL, TII.get(Mov::MOV32rm), Mov::ECX)
        .addReg(Mov::EBP)
        .addImm(IdxBaseDisp);

    // mov dl, byte ptr [sum_table + ecx]   ; lookup the sum byte
    BuildMI(MBB, I, DL, TII.get(Mov::MOV8rm_idx), Mov::DL)
        .addExternalSymbol("__mov_add8_sum_table")
        .addReg(Mov::ECX);
    // mov byte ptr [srcdst + i], dl  ; write sum back in place
    BuildMI(MBB, I, DL, TII.get(Mov::MOV8mr))
        .addReg(Mov::EBP)
        .addImm(SrcByteDisp)
        .addReg(Mov::DL);

    if (ByteIdx < 3) {
      // mov cl, byte ptr [carry_table + ecx]  ; carry-out for next stage
      BuildMI(MBB, I, DL, TII.get(Mov::MOV8rm_idx), Mov::CL)
          .addExternalSymbol("__mov_add8_carry_table")
          .addReg(Mov::ECX);
    }
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
      emitByteStage(MBB, Insert, DL, TII, *Addr, ByteIdx, ImmBytes[ByteIdx]);

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
};
} // namespace

char MovOnlyLegalize::ID = 0;

FunctionPass *llvm::createMovOnlyLegalizePass() {
  return new MovOnlyLegalize();
}
