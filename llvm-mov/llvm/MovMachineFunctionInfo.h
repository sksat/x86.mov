//===-- MovMachineFunctionInfo.h --------------------------------*- C++ -*-===//
//
// Per-function state for the Mov backend. At stage 7-prep-2c the only
// thing in here is the table of FrameIndices reserved for the
// MovOnlyLegalize pass (post-PEI) to spill parent registers into when
// it needs to use a low-byte alias (e.g. CL while ECX is live).
//
// Why a custom MachineFunctionInfo at all: MovOnlyLegalize runs at
// addPreEmitPass — after PEI, after `emitPrologue` has burned the
// `sub esp, N` value into the prologue, and after every existing
// FrameIndex has been resolved to (EBP + disp). Allocating a new
// stack object from inside the legalize pass would not be picked up
// by either side, so the slot must be reserved *before* the frame is
// finalised — `MovFrameLowering::processFunctionBeforeFrameFinalized`
// is the hook for that. The legalize pass then only *looks up* the
// FI that was reserved on its behalf.
//
//===----------------------------------------------------------------------===//

#pragma once

#include "llvm/ADT/DenseMap.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/Register.h"

namespace llvm {

class MovMachineFunctionInfo : public MachineFunctionInfo {
public:
  MovMachineFunctionInfo() = default;
  MovMachineFunctionInfo(const Function &, const TargetSubtargetInfo *) {}

  MachineFunctionInfo *
  clone(BumpPtrAllocator &Allocator, MachineFunction &DestMF,
        const DenseMap<MachineBasicBlock *, MachineBasicBlock *> &Src2DstMBB)
      const override;

  // Stage 7-prep-2c: per-function scratch-slot bookkeeping for
  // MovOnlyLegalize. The producer (MovFrameLowering's
  // processFunctionBeforeFrameFinalized) reserves a FrameIndex pre-PEI
  // and stashes it here via `setSavedParentSlotFI`. The consumer
  // (MovOnlyLegalize at addPreEmitPass) cannot use that raw FI in
  // MachineInstrs it builds — `eliminateFrameIndex` has already run by
  // then, so an FI operand would never be resolved and would reach the
  // AsmPrinter unresolved. The consumer therefore calls
  // `getSavedParentEbpDisp` (below), which combines the FI lookup with
  // `MachineFrameInfo::getObjectOffset` to return the final
  // EBP-relative displacement directly.
  //
  // Returns `-1` if no slot was reserved (legalize must skip the
  // rewrite in that case).
  int getSavedParentSlotFI(Register ParentReg) const {
    auto It = SavedParentSlots.find(ParentReg);
    return It == SavedParentSlots.end() ? -1 : It->second;
  }
  void setSavedParentSlotFI(Register ParentReg, int FI) {
    SavedParentSlots[ParentReg] = FI;
  }

  // Stage 7a1: per-function buffer the ADD32 byte-chain rewrite uses to
  // spill its operand register, run byte-wise table updates against it,
  // and load the final 32-bit result back. ADD32 is 2-address-tied
  // (dst == src1), so one 4-byte slot per function is enough. Reserved
  // pre-PEI in processFunctionBeforeFrameFinalized; `-1` means "not
  // reserved for this function" (i.e. the function had no ADD32 the
  // pre-PEI scan caught, so the legalize pass should skip).
  int getAddRewriteSrcDstFI() const { return AddRewriteSrcDstFI; }
  void setAddRewriteSrcDstFI(int FI) { AddRewriteSrcDstFI = FI; }

  // Stage 7a1: per-function slot used by the rewrite to pack the
  // (cin, a, b) index triple into 3 bytes before doing a single
  // `mov ecx, dword ptr [idx]` to load it. Builds 17-bit indices into
  // a 32-bit reg via memory because GR8 only models AL/CL/DL/BL — we
  // can't write the CH byte directly.
  int getAddRewriteIdxFI() const { return AddRewriteIdxFI; }
  void setAddRewriteIdxFI(int FI) { AddRewriteIdxFI = FI; }

  // Stage 7a1+: extra spill slot used by ADD32**rr** for the RHS
  // register operand. ADD32ri's RHS is a compile-time immediate that
  // the rewrite slices into byte-sized `mov dl, IMM8` operands;
  // ADD32rr's RHS is a generic register and needs to be spilled to
  // memory so each byte can be read with `mov dl, byte ptr
  // [rhs_buf + i]`. Reserved by MovFrameLowering only when at least
  // one rr-form byte-op (ADD/AND/OR/XOR rr) is in the function, so
  // ri-only functions stay at 16 bytes of scratch instead of 20.
  int getAddRewriteRhsFI() const { return AddRewriteRhsFI; }
  void setAddRewriteRhsFI(int FI) { AddRewriteRhsFI = FI; }

  // Stage 7b2: scratch byte used by SAR32ri to stash the sign byte
  // (0x00 or 0xFF, computed from orig[3] via __mov_sar_sign_byte at
  // the start of the rewrite). Each per-byte stage that walks "off
  // the high end" of the original 32-bit value substitutes this byte
  // in place of the orig byte that would otherwise be 0. Reserved
  // only when at least one SAR32ri *or* SAR32rCL is in the function.
  int getShiftSignBufFI() const { return ShiftSignBufFI; }
  void setShiftSignBufFI(int FI) { ShiftSignBufFI = FI; }

  // Stage 7b3: variable-shift (rCL) scratch — `amount_buf` holds the
  // initial CL value (the runtime shift count) spilled at the top of
  // the rewrite, and `shifted_buf` is the alternative 32-bit value
  // computed in each of the 5 power-of-2 stages before being merged
  // into srcdst via the mask-based select. Reserved together, only
  // when at least one SHL/SHR/SAR32rCL is in the function.
  int getShiftAmountBufFI() const { return ShiftAmountBufFI; }
  void setShiftAmountBufFI(int FI) { ShiftAmountBufFI = FI; }
  int getShiftShiftedBufFI() const { return ShiftShiftedBufFI; }
  void setShiftShiftedBufFI(int FI) { ShiftShiftedBufFI = FI; }

  // Stage 7c — branchless-dispatcher scratch. `next_pc_buf` holds the
  // code pointer that the dispatcher MBB reads on each indirect jump
  // (`jmp dword ptr [ebp + next_pc_disp]`). From stage 7c1 onwards,
  // every legalised branch ends with `mov [next_pc_buf], <target>;
  // jmp dispatcher`, and the dispatcher loads the pointer and jumps.
  // Reserved by MovFrameLowering only when the function has at least
  // one terminator (JMP/Jcc) that 7c+ legalises; pre-7c1 commits do
  // not yet allocate the slot.
  int getDispatcherNextPCBufFI() const { return DispatcherNextPCBufFI; }
  void setDispatcherNextPCBufFI(int FI) { DispatcherNextPCBufFI = FI; }

  // Stage 7c2 — `cmp_mask_buf` holds the predicate mask byte (0x00
  // or 0xFF) at offset +0 and its inverse at offset +1 during a
  // CMP+Jcc legalize site. Used by the per-byte mask-select that
  // chooses between the T-label and F-label bytes when writing to
  // `next_pc`. Reserved only when at least one CMP32{rr,ri} appears
  // in the function.
  int getCmpMaskBufFI() const { return CmpMaskBufFI; }
  void setCmpMaskBufFI(int FI) { CmpMaskBufFI = FI; }

  // Stage 7f — `mul_rhs2_buf` is the 4-byte spill of the second
  // operand for MUL32rr (rhs_buf holds the first operand). MUL32ri
  // gets the rhs bytes from the immediate slice, so this slot is
  // only allocated when the function contains MUL32rr.
  int getMulRhs2BufFI() const { return MulRhs2BufFI; }
  void setMulRhs2BufFI(int FI) { MulRhs2BufFI = FI; }

  // Stage 7f — `mul_temp_buf` is a 4-byte scratch slot. The byte
  // legalize uses [0] to stash the per-pair high byte
  // (`__mov_mul8_hi_table[a*256+b]`) before running the low-byte
  // cascade — the cascade clobbers ECX, so the high lookup result
  // has to live in memory until the low cascade is done. Reserved
  // whenever the function contains any MUL32{rr,ri}.
  int getMulTempBufFI() const { return MulTempBufFI; }
  void setMulTempBufFI(int FI) { MulTempBufFI = FI; }

private:
  // Keyed on the *parent* (full-width) physreg, e.g. Mov::ECX for the
  // slot that backs CL-uses. We don't key by the byte subreg because
  // every legalize site already knows which 32-bit reg it's borrowing
  // from, and one parent reg only ever needs one save slot per
  // function (sequential CL uses can reload between them).
  DenseMap<Register, int> SavedParentSlots;

  int AddRewriteSrcDstFI = -1;
  int AddRewriteIdxFI = -1;
  int AddRewriteRhsFI = -1;
  int ShiftSignBufFI = -1;
  int ShiftAmountBufFI = -1;
  int ShiftShiftedBufFI = -1;
  int DispatcherNextPCBufFI = -1;
  int CmpMaskBufFI = -1;
  int MulRhs2BufFI = -1;
  int MulTempBufFI = -1;
};

} // namespace llvm
