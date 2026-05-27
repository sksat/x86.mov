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
        // SUB rr/ri, SHL/SHR/SAR ri/rCL, CMP+Jcc, CALL32d + CALLSEQ,
        // RET, and the prologue/epilogue PUSH/POP/SUB/MOV sequence
        // light up across stages 7b2 → 7d.
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
  // is only populated when the function has at least one ADD32rr —
  // ADD32ri-only functions leave it nullopt.
  struct EbpAddr {
    int64_t SaveEcxDisp;
    int64_t SaveEdxDisp;
    int64_t SrcDstDisp;
    int64_t IdxDisp;
    std::optional<int64_t> RhsDisp;
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
    EbpAddr A{MFI.getObjectOffset(FI_Ecx), MFI.getObjectOffset(FI_Edx),
              MFI.getObjectOffset(FI_Sd), MFI.getObjectOffset(FI_Ix),
              std::nullopt};
    const int FI_Rhs = MovMFI->getAddRewriteRhsFI();
    if (FI_Rhs != -1)
      A.RhsDisp = MFI.getObjectOffset(FI_Rhs);
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

  // Helper: zero ECX, then zero the idx slot. After this returns,
  // ECX = 0 and idx[0..3] = 0. DL is untouched (callers that need to
  // preserve CL into DL before zeroing must do so themselves).
  static void emitIdxZero(MachineBasicBlock &MBB,
                          MachineBasicBlock::iterator I, const DebugLoc &DL,
                          const TargetInstrInfo &TII, const EbpAddr &A) {
    // mov ecx, 0
    BuildMI(MBB, I, DL, TII.get(Mov::MOV32ri), Mov::ECX).addImm(0);
    // mov dword ptr [idx], ecx
    BuildMI(MBB, I, DL, TII.get(Mov::MOV32mr))
        .addReg(Mov::EBP)
        .addImm(A.IdxDisp)
        .addReg(Mov::ECX);
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
  //   - byte 0 has no carry-in — skip the `mov dl, cl` preserve and
  //     the `mov [idx+2], dl` write. emitIdxZero zeros idx[2] anyway.
  //   - byte 3 doesn't need carry-out — skip the trailing load.
  static void emitByteStageAdd(MachineBasicBlock &MBB,
                               MachineBasicBlock::iterator I,
                               const DebugLoc &DL,
                               const TargetInstrInfo &TII, const EbpAddr &A,
                               unsigned ByteIdx, ByteSource BSrc) {
    if (ByteIdx > 0) {
      // mov dl, cl              ; preserve carry across the next ECX zero
      BuildMI(MBB, I, DL, TII.get(Mov::MOV8rr), Mov::DL).addReg(Mov::CL);
    }
    emitIdxZero(MBB, I, DL, TII, A);
    if (ByteIdx > 0) {
      // mov byte ptr [idx + 2], dl   ; carry-in byte
      BuildMI(MBB, I, DL, TII.get(Mov::MOV8mr))
          .addReg(Mov::EBP)
          .addImm(A.IdxDisp + 2)
          .addReg(Mov::DL);
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
};
} // namespace

char MovOnlyLegalize::ID = 0;

FunctionPass *llvm::createMovOnlyLegalizePass() {
  return new MovOnlyLegalize();
}
