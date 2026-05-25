//===-- MovISelDAGToDAG.cpp -----------------------------------------------===//
//
// SelectionDAG → MachineInstr selector for the Mov target. The bulk of the
// work is the TableGen-generated `SelectCode`; we just plug in the harness.
//
// In LLVM 22 the pass wrapper changed shape: `SelectionDAGISel` is no longer a
// FunctionPass on its own — `SelectionDAGISelLegacy` is the pass-manager-side
// wrapper that owns one of our `SelectionDAGISel` impls. `getPassName` lives
// on the wrapper.
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/MovMCTargetDesc.h"
#include "MovSubtarget.h"
#include "MovTargetMachine.h"
#include "llvm/CodeGen/SelectionDAG.h"
#include "llvm/CodeGen/SelectionDAGISel.h"
#include "llvm/Support/Debug.h"

#define DEBUG_TYPE "mov-isel"

using namespace llvm;

namespace {
class MovDAGToDAGISel : public SelectionDAGISel {
public:
  MovDAGToDAGISel(MovTargetMachine &TM, CodeGenOptLevel OptLevel)
      : SelectionDAGISel(TM, OptLevel) {}

  void Select(SDNode *Node) override;

  // Address-mode selector referenced from MovInstrInfo.td's `addr_fi`
  // ComplexPattern. Stage 2 only matches plain FrameIndex addresses;
  // (base+disp) and (base+index*scale) come in at later stages.
  bool SelectAddrFI(SDValue Addr, SDValue &Base, SDValue &Disp);

// Auto-generated `SelectCode` (used by `Select`).
#include "MovGenDAGISel.inc"
};

class MovDAGToDAGISelLegacy : public SelectionDAGISelLegacy {
public:
  static char ID;
  explicit MovDAGToDAGISelLegacy(MovTargetMachine &TM,
                                 CodeGenOptLevel OptLevel)
      : SelectionDAGISelLegacy(ID,
                               std::make_unique<MovDAGToDAGISel>(TM, OptLevel)) {}

  StringRef getPassName() const override {
    return "Mov DAG->DAG Instruction Selection";
  }
};
} // namespace

char MovDAGToDAGISelLegacy::ID = 0;

void MovDAGToDAGISel::Select(SDNode *Node) {
  // If pre-selection custom matching is ever needed (e.g. fancier ADDR modes),
  // do it here. For stage 0–2 the TableGen-generated patterns cover everything.
  SelectCode(Node);
}

bool MovDAGToDAGISel::SelectAddrFI(SDValue Addr, SDValue &Base, SDValue &Disp) {
  if (auto *FIN = dyn_cast<FrameIndexSDNode>(Addr)) {
    Base = CurDAG->getTargetFrameIndex(FIN->getIndex(),
                                       TLI->getPointerTy(CurDAG->getDataLayout()));
    Disp = CurDAG->getTargetConstant(0, SDLoc(Addr), MVT::i32);
    return true;
  }
  return false;
}

FunctionPass *llvm::createMovISelDag(MovTargetMachine &TM,
                                     CodeGenOptLevel OptLevel) {
  return new MovDAGToDAGISelLegacy(TM, OptLevel);
}
