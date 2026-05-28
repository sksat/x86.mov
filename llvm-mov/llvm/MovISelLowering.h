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

  // Branch-on-condition. Operand layout (after the chain):
  //   0: CondCode (ISD::CondCode wrapped in OtherVT)
  //   1: LHS (i32)
  //   2: RHS (i32)
  //   3: target MachineBasicBlock
  //
  // Mirrors ISD::BR_CC but is a target node so we can intercept it in
  // MovDAGToDAGISel::Select and emit `CMP + Jcc` directly, with the
  // EFLAGS dependence pinned via SDValue glue.
  BR_CC,

  // Direct cdecl call. Operand 0 is the callee symbol (MO_GlobalAddress
  // or MO_ExternalSymbol); the variadic tail carries the register-mask
  // operand and any CopyToReg chain LowerCall set up. Selection picks
  // CALL32d.
  CALL,
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

  // Stage 6a: lower a direct cdecl call. Scope is tight on purpose —
  // CallingConv::C only, fixed args (no vararg), scalar i1/i8/i16/i32
  // args and return, no sret/byval/tailcall/fastcc. Anything outside
  // the supported set raises report_fatal_error.
  SDValue LowerCall(CallLoweringInfo &CLI,
                    SmallVectorImpl<SDValue> &InVals) const override;

  // Custom-lowered operations: ISD::BRCOND and ISD::BR_CC both fold
  // into MovISD::BR_CC; the selector then emits a CMP + Jcc pair.
  SDValue LowerOperation(SDValue Op, SelectionDAG &DAG) const override;
  SDValue LowerBRCOND(SDValue Op, SelectionDAG &DAG) const;
  SDValue LowerBR_CC(SDValue Op, SelectionDAG &DAG) const;

  // Stop DAGCombiner from rewriting `(and (load i32), 0xFF)` or
  // `(lshr (load i32), 16)` into a narrow ext-load — our backend has no
  // movzx/movsx-style instruction yet, so a narrow load is unrepresentable.
  // See MovISelLowering.cpp for the why (codex stage-3 review feedback).
  bool shouldReduceLoadWidth(
      SDNode *Load, ISD::LoadExtType ExtTy, EVT NewVT,
      std::optional<unsigned> ByteOffset = std::nullopt) const override {
    return false;
  }

  // Stage 6d3 — advertise that x86 supports unaligned memory access at
  // the hardware level. Without this, the DAG legalizer treats an
  // `align 1` i32 load as misaligned and tries to break it into four
  // i8 loads (which our backend doesn't yet lower cleanly — the i8
  // extload path hits "Cannot select" and hangs the type legalizer
  // on multi-byte fragments). With this override, the unaligned i32
  // load survives as a single load + a MOV32rm selection — slow on
  // real hardware but always correct, and the only path that lets
  // byte-stream-reading Rust code (`ptr::read_unaligned::<u32>`)
  // compile through our backend without first solving native i8
  // ext-loads.
  bool allowsMisalignedMemoryAccesses(EVT, unsigned AddrSpace = 0,
                                      Align Alignment = Align(1),
                                      MachineMemOperand::Flags = MachineMemOperand::MONone,
                                      unsigned *Fast = nullptr) const override {
    if (Fast)
      *Fast = 1;
    return true;
  }

  const char *getTargetNodeName(unsigned Opcode) const override;
};
} // namespace llvm
