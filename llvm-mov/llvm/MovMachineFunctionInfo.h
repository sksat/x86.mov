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

private:
  // Keyed on the *parent* (full-width) physreg, e.g. Mov::ECX for the
  // slot that backs CL-uses. We don't key by the byte subreg because
  // every legalize site already knows which 32-bit reg it's borrowing
  // from, and one parent reg only ever needs one save slot per
  // function (sequential CL uses can reload between them).
  DenseMap<Register, int> SavedParentSlots;
};

} // namespace llvm
