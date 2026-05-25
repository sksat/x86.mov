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

  // Stop DAGCombiner from rewriting `(and (load i32), 0xFF)` or
  // `(lshr (load i32), 16)` into a narrow ext-load — our backend has no
  // movzx/movsx-style instruction yet, so a narrow load is unrepresentable.
  // See MovISelLowering.cpp for the why (codex stage-3 review feedback).
  bool shouldReduceLoadWidth(
      SDNode *Load, ISD::LoadExtType ExtTy, EVT NewVT,
      std::optional<unsigned> ByteOffset = std::nullopt) const override {
    return false;
  }

  const char *getTargetNodeName(unsigned Opcode) const override;
};
} // namespace llvm
