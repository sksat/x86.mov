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
  // MovOnlyLegalize. `getSavedParentSlot(ParentReg)` returns the
  // FrameIndex reserved to hold `ParentReg`'s value while the legalize
  // pass borrows the low byte (e.g. spill ECX, then use CL as a table
  // index, then reload ECX from the slot). `-1` means "no slot has
  // been reserved" — the legalize pass is required to either reserve
  // one (via the FrameLowering hook) or skip the rewrite. Storing the
  // slot here, rather than recomputing it from MachineFrameInfo on
  // every query, keeps the rewrite paths short and avoids any
  // dependence on FI ordering.
  int getSavedParentSlot(Register ParentReg) const {
    auto It = SavedParentSlots.find(ParentReg);
    return It == SavedParentSlots.end() ? -1 : It->second;
  }
  void setSavedParentSlot(Register ParentReg, int FI) {
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
