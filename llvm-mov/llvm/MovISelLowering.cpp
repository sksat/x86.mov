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

  // Without these, DAGCombine cheerfully folds `(and (load i32), 255)` and
  // `(lshr (load i32), 16)` into ZEXTLOAD/SEXTLOAD/EXTLOAD-from-i8/i16
  // patterns that MOV32rm doesn't match — codex's stage-3 review caught
  // both `and i32 %x, 255` and `lshr %x, 16` crashing with "Cannot select"
  // on the resulting narrow ext-load. Marking the narrow ext-load forms
  // Expand keeps DAGCombine from forming them in the first place, so the
  // arithmetic stays as a plain `load + and/lshr` pair that our existing
  // MOV32rm + ADD32ri/AND32ri/etc. patterns cover. Narrow loads
  // re-enable as Legal at stage 3.5 alongside narrow-int support proper.
  for (MVT MemVT : {MVT::i1, MVT::i8, MVT::i16}) {
    setLoadExtAction(ISD::EXTLOAD,  MVT::i32, MemVT, Expand);
    setLoadExtAction(ISD::ZEXTLOAD, MVT::i32, MemVT, Expand);
    setLoadExtAction(ISD::SEXTLOAD, MVT::i32, MemVT, Expand);
  }

  // x86 normally lowers `sign_extend_inreg` to `movsx`, which we don't
  // have. Without an action, signed narrow consumers — `sext i8 to i32`,
  // `signext i8` returns, `ashr i8` — would crash with "Cannot select
  // sign_extend_inreg" the moment stage 3.5 enabled narrow ABI values.
  // Expand lets the legalizer rewrite the node into the standard
  // `shl-N; sar-N` pair (which our SHL32ri/SAR32ri already cover) and
  // keeps the mov-heavy ISA honest about not having movsx.
  setOperationAction(ISD::SIGN_EXTEND_INREG, MVT::i1, Expand);
  setOperationAction(ISD::SIGN_EXTEND_INREG, MVT::i8, Expand);
  setOperationAction(ISD::SIGN_EXTEND_INREG, MVT::i16, Expand);
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

  for (CCValAssign &VA : ArgLocs) {
    if (!VA.isMemLoc()) {
      // Register-passed args land at stage 6 — until then CC_Mov assigns
      // everything to the stack, so a reg-loc here means the CC table and
      // this lowering have diverged.
      report_fatal_error("Mov: register-passed formal arg unexpected");
    }

    // cdecl: each i32 (incl. promoted i1/i8/i16) arg occupies one 4-byte
    // stack slot. Right after `call`, callee's [esp+0] holds the return
    // address and [esp+4] holds arg0 — VA.getLocMemOffset() is the offset
    // *from arg0*, so the on-stack location of this arg is
    // (4 + LocMemOffset). eliminateFrameIndex resolves the FI to the
    // matching [esp + n] later (frame size is 0 at stage 2/3 so the
    // fixed-object offset translates 1:1).
    const unsigned Size = VA.getLocVT().getStoreSize();
    const int FI = MFI.CreateFixedObject(Size, 4 + VA.getLocMemOffset(),
                                         /*IsImmutable=*/true);

    SDValue FIN = DAG.getFrameIndex(FI, getPointerTy(DAG.getDataLayout()));
    SDValue Arg = DAG.getLoad(VA.getLocVT(), DL, Chain, FIN,
                              MachinePointerInfo::getFixedStack(MF, FI));

    // Stage 3.5: if CC_Mov promoted a narrow integer to i32, the load
    // returned an i32 but the IR-level consumer expects the original
    // narrow VT — TRUNCATE back so SelectionDAGBuilder's bookkeeping
    // lines up. (LocInfo distinguishes Full from {AExt, ZExt, SExt}; in
    // all three "Ext" cases the in-register value's low bits are the
    // payload, so a plain truncate is correct.)
    if (VA.getLocInfo() != CCValAssign::Full)
      Arg = DAG.getNode(ISD::TRUNCATE, DL, VA.getValVT(), Arg);
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
    SDValue Val = OutVals[i];
    // Stage 3.5: narrow returns (i1/i8/i16) get promoted by RetCC_Mov to
    // i32 in EAX. The caller only looks at the low bits — `i8 add` of
    // 250+10 has to truncate-wrap to 4 — but we still need to widen
    // the value before CopyToReg because EAX is i32. ANY_EXTEND keeps
    // the high bits as don't-care, which is what the cdecl return
    // contract allows.
    switch (VA.getLocInfo()) {
    case CCValAssign::Full:
      break;
    case CCValAssign::AExt:
      Val = DAG.getNode(ISD::ANY_EXTEND, DL, VA.getLocVT(), Val);
      break;
    case CCValAssign::ZExt:
      Val = DAG.getNode(ISD::ZERO_EXTEND, DL, VA.getLocVT(), Val);
      break;
    case CCValAssign::SExt:
      Val = DAG.getNode(ISD::SIGN_EXTEND, DL, VA.getLocVT(), Val);
      break;
    default:
      report_fatal_error("Mov: unexpected CCValAssign::LocInfo in LowerReturn");
    }
    Chain = DAG.getCopyToReg(Chain, DL, VA.getLocReg(), Val, Glue);
    Glue  = Chain.getValue(1);
    RetOps.push_back(DAG.getRegister(VA.getLocReg(), VA.getLocVT()));
  }

  if (Glue.getNode())
    RetOps.push_back(Glue);

  return DAG.getNode(MovISD::RET, DL, MVT::Other, RetOps);
}
