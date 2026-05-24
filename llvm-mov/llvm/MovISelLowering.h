//===-- MovISelLowering.h ---------------------------------------*- C++ -*-===//
#pragma once

#include "llvm/CodeGen/TargetLowering.h"

namespace llvm {
class MovSubtarget;
class MovTargetMachine;

namespace MovISD {
enum NodeType : unsigned {
  FIRST_NUMBER = ISD::BUILTIN_OP_END,
  RET,  // Custom return node — picked up by the RET pattern in MovInstrInfo.td.
};
} // namespace MovISD

class MovTargetLowering : public TargetLowering {
public:
  MovTargetLowering(const TargetMachine &TM, const MovSubtarget &STI);

  SDValue LowerFormalArguments(SDValue Chain, CallingConv::ID CallConv,
                               bool IsVarArg,
                               const SmallVectorImpl<ISD::InputArg> &Ins,
                               const SDLoc &DL, SelectionDAG &DAG,
                               SmallVectorImpl<SDValue> &InVals) const override;

  SDValue LowerReturn(SDValue Chain, CallingConv::ID CallConv, bool IsVarArg,
                      const SmallVectorImpl<ISD::OutputArg> &Outs,
                      const SmallVectorImpl<SDValue> &OutVals,
                      const SDLoc &DL,
                      SelectionDAG &DAG) const override;

  const char *getTargetNodeName(unsigned Opcode) const override;
};
} // namespace llvm
