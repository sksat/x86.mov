//===-- MovMachineFunctionInfo.cpp ----------------------------------------===//
//
// Out-of-line clone() so the vtable has a key function and only one TU
// emits it, per the usual C++ ODR convention.
//
//===----------------------------------------------------------------------===//

#include "MovMachineFunctionInfo.h"

using namespace llvm;

MachineFunctionInfo *MovMachineFunctionInfo::clone(
    BumpPtrAllocator &Allocator, MachineFunction &DestMF,
    const DenseMap<MachineBasicBlock *, MachineBasicBlock *> & /*Src2DstMBB*/)
    const {
  return DestMF.cloneInfo<MovMachineFunctionInfo>(*this);
}
