//===-- MovISelLowering.cpp -----------------------------------------------===//
//
// Stage-0 lowering: no formal arguments handled, return values handled for
// i32 only (CCAssignToReg<[EAX]> via RetCC_Mov). Calls aren't lowered yet —
// they'll come in stage 6.
//
//===----------------------------------------------------------------------===//

#include "MovISelLowering.h"
#include "MCTargetDesc/MovMCTargetDesc.h"
#include "MovSubtarget.h"
#include "llvm/CodeGen/CallingConvLower.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/SelectionDAG.h"
#include "llvm/CodeGen/TargetLoweringObjectFileImpl.h"
#include "llvm/IR/DiagnosticInfo.h"
#include "llvm/Support/ErrorHandling.h"

using namespace llvm;

// TableGen-generated calling-conv dispatchers (CC_Mov, RetCC_Mov).
#include "MovGenCallingConv.inc"

MovTargetLowering::MovTargetLowering(const TargetMachine &TM,
                                     const MovSubtarget &STI)
    : TargetLowering(TM, STI) {
  addRegisterClass(MVT::i32, &Mov::GPR32RegClass);
  computeRegisterProperties(STI.getRegisterInfo());

  setStackPointerRegisterToSaveRestore(Mov::ESP);
  setBooleanContents(ZeroOrOneBooleanContent);

  // Stage 0 reuses LLVM's default expansions; we only override what we need
  // explicitly. Add Custom hooks here as later stages introduce them.
}

const char *MovTargetLowering::getTargetNodeName(unsigned Opcode) const {
  switch (Opcode) {
  case MovISD::RET: return "MovISD::RET";
  default:          return nullptr;
  }
}

SDValue MovTargetLowering::LowerFormalArguments(
    SDValue Chain, CallingConv::ID CallConv, bool /*IsVarArg*/,
    const SmallVectorImpl<ISD::InputArg> &Ins, const SDLoc &DL,
    SelectionDAG &DAG, SmallVectorImpl<SDValue> &InVals) const {
  MachineFunction &MF = DAG.getMachineFunction();
  MachineFrameInfo &MFI = MF.getFrameInfo();

  SmallVector<CCValAssign, 8> ArgLocs;
  CCState CCInfo(CallConv, /*IsVarArg=*/false, MF, ArgLocs,
                 *DAG.getContext());
  CCInfo.AnalyzeFormalArguments(Ins, CC_Mov);

  // Reject anything that isn't a real i32 in the IR. SelectionDAG type-
  // legalizes i1/i8/i16 → i32 before CC dispatch, so CC_Mov / ArgLocs
  // can't see the original narrow type — but DAGCombiner can still fold
  // a downstream trunc+ext into an extending load that MOV32rm doesn't
  // match, and we'd silently miscompile. Ins[i].ArgVT preserves the
  // pre-legalization type, so check there.
  for (size_t i = 0; i < Ins.size(); ++i) {
    if (Ins[i].ArgVT.getSimpleVT() != MVT::i32)
      report_fatal_error(
          "Mov: only i32 formal args supported at stage 2 "
          "(narrow integer args land at stage 3 with extending-load patterns)");
  }

  for (CCValAssign &VA : ArgLocs) {
    if (!VA.isMemLoc()) {
      // Register-passed args land at stage 6 — until then CC_Mov assigns
      // everything to the stack, so a reg-loc here means the CC table and
      // this lowering have diverged.
      report_fatal_error("Mov: register-passed formal arg unexpected");
    }

    // cdecl: each i32 arg occupies one 4-byte stack slot. Right after
    // `call`, callee's [esp+0] holds the return address and [esp+4]
    // holds arg0 — VA.getLocMemOffset() is the offset *from arg0*, so
    // the on-stack location of this arg is (4 + LocMemOffset). That's
    // exactly what eliminateFrameIndex resolves later (frame size is 0
    // at stage 2 so the fixed-object offset translates 1:1).
    const unsigned Size = VA.getLocVT().getStoreSize();
    const int FI = MFI.CreateFixedObject(Size, 4 + VA.getLocMemOffset(),
                                         /*IsImmutable=*/true);

    SDValue FIN = DAG.getFrameIndex(FI, getPointerTy(DAG.getDataLayout()));
    SDValue Arg = DAG.getLoad(VA.getLocVT(), DL, Chain, FIN,
                              MachinePointerInfo::getFixedStack(MF, FI));
    InVals.push_back(Arg);
  }
  return Chain;
}

SDValue MovTargetLowering::LowerReturn(
    SDValue Chain, CallingConv::ID CallConv, bool /*IsVarArg*/,
    const SmallVectorImpl<ISD::OutputArg> &Outs,
    const SmallVectorImpl<SDValue> &OutVals, const SDLoc &DL,
    SelectionDAG &DAG) const {
  SmallVector<CCValAssign, 4> RVLocs;
  CCState CCInfo(CallConv, /*IsVarArg=*/false, DAG.getMachineFunction(), RVLocs,
                 *DAG.getContext());
  CCInfo.AnalyzeReturn(Outs, RetCC_Mov);

  SmallVector<SDValue, 4> RetOps;
  RetOps.push_back(Chain);

  SDValue Glue;
  for (unsigned i = 0, e = RVLocs.size(); i != e; ++i) {
    CCValAssign &VA = RVLocs[i];
    assert(VA.isRegLoc() && "stage 0 RetCC always assigns to a register");
    Chain = DAG.getCopyToReg(Chain, DL, VA.getLocReg(), OutVals[i], Glue);
    Glue  = Chain.getValue(1);
    RetOps.push_back(DAG.getRegister(VA.getLocReg(), VA.getLocVT()));
  }

  if (Glue.getNode())
    RetOps.push_back(Glue);

  return DAG.getNode(MovISD::RET, DL, MVT::Other, RetOps);
}
