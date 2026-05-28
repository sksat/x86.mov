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

  // Narrow ext-load policy.
  //
  // Stage 3 ran with everything Expand: real Rust code didn't have i8
  // load/store sites because i8 ABI values were promoted through i32
  // slots (no narrow memory). DAGCombine then couldn't fold `(and (load
  // i32), 255)` into ZEXTLOAD-i8, which would have hit "Cannot select".
  //
  // Stage 6c flips i8 ZEXTLOAD / EXTLOAD to Legal so Rust crate code
  // that does honest byte-load (e.g. `arr[i]` where `arr: [u8; N]`)
  // selects via the patterns added in MovInstrInfo.td (zextloadi8 →
  // `mov DST32, 0; mov DST8, [m]`). SEXTLOAD-i8 stays Expand because
  // we have no `movsx`; the legalizer rewrites signed byte loads to
  // `zextloadi8` + sign_extend_inreg, which then expands again to
  // shl-24 / sar-24 — all selectable via existing patterns. The i16
  // forms stay Expand for now: real Rust code rarely emits them, and
  // adding them is a separate stage.
  setLoadExtAction(ISD::EXTLOAD,  MVT::i32, MVT::i8, Legal);
  setLoadExtAction(ISD::ZEXTLOAD, MVT::i32, MVT::i8, Legal);
  setLoadExtAction(ISD::SEXTLOAD, MVT::i32, MVT::i8, Expand);
  for (MVT MemVT : {MVT::i1, MVT::i16}) {
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

  // Stage 5: fold (BRCOND (SETCC a, b, cc) bb) into MovISD::BR_CC so the
  // selector can emit a glued CMP + Jcc pair. SETCC on its own (without
  // a BRCOND consumer — e.g. `select` or `zext i1`) isn't supported yet;
  // that's stage 5.5.
  //
  // We mark BOTH BRCOND and BR_CC Custom because the DAG legalizer
  // sometimes rewrites BRCOND(SETCC(...)) into BR_CC before our hook
  // gets a turn (especially when SETCC.i32 is Expand). Hooking both
  // sides means either shape ends up in MovISD::BR_CC.
  setOperationAction(ISD::BRCOND, MVT::Other, Custom);
  setOperationAction(ISD::BR_CC,  MVT::i32,   Custom);
  setOperationAction(ISD::SETCC,  MVT::i32,   Expand);

  // No CMOVcc — Expand SELECT / SELECT_CC into the standard
  // branch + PHI shape (BRCOND target_bb, fallthrough). The
  // resulting BRCOND/BR_CC pair flows back through our existing
  // Custom hook above, so a `select` IR node ends up as a CMP +
  // Jcc + branch sequence (eventually mov-only-legalized by 7c2).
  setOperationAction(ISD::SELECT,    MVT::i32, Expand);
  setOperationAction(ISD::SELECT_CC, MVT::i32, Expand);
}

SDValue MovTargetLowering::LowerOperation(SDValue Op, SelectionDAG &DAG) const {
  switch (Op.getOpcode()) {
  case ISD::BRCOND:
    return LowerBRCOND(Op, DAG);
  case ISD::BR_CC:
    return LowerBR_CC(Op, DAG);
  default:
    llvm_unreachable("Mov: LowerOperation called on unhandled opcode");
  }
}

SDValue MovTargetLowering::LowerBRCOND(SDValue Op, SelectionDAG &DAG) const {
  // BRCOND operand layout: (chain, cond, target_bb)
  SDValue Chain  = Op.getOperand(0);
  SDValue Cond   = Op.getOperand(1);
  SDValue Target = Op.getOperand(2);
  SDLoc DL(Op);

  ISD::CondCode CC;
  SDValue LHS, RHS;
  if (Cond.getOpcode() == ISD::SETCC) {
    // The common case: `br i1 (icmp cc a, b)` lowers as
    // BRCOND(SETCC(a, b, cc), bb). Pull cc/a/b out and pack them into
    // MovISD::BR_CC so we can emit a single CMP + Jcc pair.
    LHS = Cond.getOperand(0);
    RHS = Cond.getOperand(1);
    CC  = cast<CondCodeSDNode>(Cond.getOperand(2))->get();
  } else {
    // `br i1 %v` where %v isn't a SETCC: branch when %v is non-zero.
    // We synthesize `CMP %v, 0; JNE` by lowering through BR_CC with
    // SETNE against a literal 0.
    LHS = Cond;
    RHS = DAG.getConstant(0, DL, MVT::i32);
    CC  = ISD::SETNE;
  }

  return DAG.getNode(MovISD::BR_CC, DL, MVT::Other, Chain,
                     DAG.getCondCode(CC), LHS, RHS, Target);
}

SDValue MovTargetLowering::LowerBR_CC(SDValue Op, SelectionDAG &DAG) const {
  // ISD::BR_CC operand layout: (chain, cc, lhs, rhs, target_bb).
  // Repack as MovISD::BR_CC; the selector emits CMP + Jcc.
  SDValue Chain  = Op.getOperand(0);
  SDValue CCNode = Op.getOperand(1);
  SDValue LHS    = Op.getOperand(2);
  SDValue RHS    = Op.getOperand(3);
  SDValue Target = Op.getOperand(4);
  SDLoc DL(Op);
  return DAG.getNode(MovISD::BR_CC, DL, MVT::Other,
                     Chain, CCNode, LHS, RHS, Target);
}

const char *MovTargetLowering::getTargetNodeName(unsigned Opcode) const {
  switch (Opcode) {
  case MovISD::RET:   return "MovISD::RET";
  case MovISD::BR_CC: return "MovISD::BR_CC";
  case MovISD::CALL:  return "MovISD::CALL";
  default:            return nullptr;
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

  for (size_t i = 0; i < ArgLocs.size(); ++i) {
    CCValAssign &VA = ArgLocs[i];
    const ISD::ArgFlagsTy &Flags = Ins[i].Flags;
    if (!VA.isMemLoc()) {
      // Register-passed args land at stage 6 — until then CC_Mov assigns
      // everything to the stack, so a reg-loc here means the CC table and
      // this lowering have diverged.
      report_fatal_error("Mov: register-passed formal arg unexpected");
    }

    // Stage 6b — byval formal arg. The struct's bytes are at
    // [esp + 4 + locmem-offset]; the IR-level callee receives a
    // pointer to that location (a FrameIndex pointer, lowered to
    // [ebp + …] post-PEI). Allocate the FixedObject at the struct's
    // full size so PEI's stack-size computation accounts for it.
    if (Flags.isByVal()) {
      const unsigned Size = Flags.getByValSize();
      const int FI = MFI.CreateFixedObject(Size, 4 + VA.getLocMemOffset(),
                                           /*IsImmutable=*/false);
      SDValue FIN = DAG.getFrameIndex(FI, getPointerTy(DAG.getDataLayout()));
      InVals.push_back(FIN);
      continue;
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
      report_fatal_error(Twine("Mov: unexpected CCValAssign::LocInfo=") +
                         Twine(static_cast<int>(VA.getLocInfo())) +
                         " in LowerReturn (ValVT=" +
                         Twine(VA.getValVT().SimpleTy) +
                         ", LocVT=" +
                         Twine(VA.getLocVT().SimpleTy) + ")");
    }
    Chain = DAG.getCopyToReg(Chain, DL, VA.getLocReg(), Val, Glue);
    Glue  = Chain.getValue(1);
    RetOps.push_back(DAG.getRegister(VA.getLocReg(), VA.getLocVT()));
  }

  if (Glue.getNode())
    RetOps.push_back(Glue);

  return DAG.getNode(MovISD::RET, DL, MVT::Other, RetOps);
}

//===----------------------------------------------------------------------===//
// LowerCall — stage 6a, cdecl, direct, scalar-only.
//===----------------------------------------------------------------------===//

SDValue MovTargetLowering::LowerCall(CallLoweringInfo &CLI,
                                     SmallVectorImpl<SDValue> &InVals) const {
  SelectionDAG &DAG = CLI.DAG;
  SDLoc &DL = CLI.DL;
  SDValue Chain = CLI.Chain;
  SDValue Callee = CLI.Callee;
  CallingConv::ID CallConv = CLI.CallConv;
  bool &IsTailCall = CLI.IsTailCall;
  const auto &Outs = CLI.Outs;
  const auto &OutVals = CLI.OutVals;
  const auto &Ins = CLI.Ins;
  MachineFunction &MF = DAG.getMachineFunction();

  // Stage 6a scope guards. Codex's stage-6 design pass insisted on hard
  // rejection here so any out-of-scope IR fails with a readable diagnostic
  // rather than mis-compiling.
  if (CallConv != CallingConv::C)
    report_fatal_error(
        "Mov: only CallingConv::C supported (stage 6a; fastcall/etc. later)");
  if (CLI.IsVarArg)
    report_fatal_error("Mov: vararg calls not yet supported (stage 6+)");
  for (const ISD::OutputArg &O : Outs) {
    // Stage 6b — accept sret + byval. sret is just a pointer arg
    // (caller-allocated return slot, pushed as the first cdecl arg);
    // byval is handled below by emitting a `getMemcpy` from the
    // source pointer to the outgoing stack slot instead of a plain
    // store. Both flags are common in Rust IR (trait returns
    // bigger than 4 bytes become sret; `&struct` borrowed args
    // sometimes use byval).
    if (O.Flags.isSRet()) {
      // sret pointer — just a regular i32 pointer arg from here on.
      // Don't apply the scalar-VT check; the pointer's VT is i32.
      continue;
    }
    if (O.Flags.isByVal()) {
      // byval — the per-arg loop below emits getMemcpy. The VT here
      // is just the pointer; the byval-size lives in Flags.
      continue;
    }
    if (O.VT != MVT::i1 && O.VT != MVT::i8 && O.VT != MVT::i16 &&
        O.VT != MVT::i32)
      report_fatal_error(
          "Mov: only i1/i8/i16/i32 scalar call args supported (stage 6a)");
  }
  // Stage 6b — two-i32 returns (EDX:EAX) are accepted now. RetCC_Mov
  // assigns the second i32 to EDX. Bigger aggregate returns route
  // through sret (handled above as a regular pointer arg).
  if (Ins.size() > 2)
    report_fatal_error(
        "Mov: returns wider than EDX:EAX must use sret (stage 6b only "
        "handles up to 8-byte register returns)");

  // Tail-call elimination not implemented; CallLoweringInfo asks us to
  // unset the flag rather than silently keep emitting a tail call.
  IsTailCall = false;

  // Analyze outgoing args against CC_Mov.
  SmallVector<CCValAssign, 8> ArgLocs;
  CCState CCInfo(CallConv, /*IsVarArg=*/false, MF, ArgLocs, *DAG.getContext());
  CCInfo.AnalyzeCallOperands(Outs, CC_Mov);
  const unsigned NumBytes = CCInfo.getStackSize();

  // CALLSEQ_START(NumBytes, 0) — reserves the outgoing-arg area.
  Chain = DAG.getCALLSEQ_START(Chain, NumBytes, 0, DL);

  // For each stack-passed arg, compute its address as ESP + offset and emit
  // a store. cdecl pushes are caller-cleaned; we emit them as plain stores
  // so DAGCombine can keep them in order via the chain.
  SmallVector<SDValue, 8> MemOpChains;
  const SDValue StackPtr =
      DAG.getCopyFromReg(Chain, DL, Mov::ESP,
                         getPointerTy(DAG.getDataLayout()));

  for (size_t i = 0; i < ArgLocs.size(); ++i) {
    CCValAssign &VA = ArgLocs[i];
    SDValue Arg = OutVals[i];
    const ISD::ArgFlagsTy &Flags = Outs[i].Flags;

    if (!VA.isMemLoc())
      report_fatal_error("Mov: register-passed call args unexpected (stage 6+)");

    // Stage 6b — byval struct passing. Source is a pointer to the
    // caller's struct; cdecl wants the struct's bytes copied to the
    // outgoing arg slot. Emit a getMemcpy and skip the scalar
    // extend/store path below.
    if (Flags.isByVal()) {
      const unsigned Size = Flags.getByValSize();
      const Align Alignment = Flags.getNonZeroByValAlign();
      SDValue SizeNode = DAG.getIntPtrConstant(Size, DL);
      SDValue Offset = DAG.getIntPtrConstant(VA.getLocMemOffset(), DL);
      SDValue Dst = DAG.getNode(ISD::ADD, DL,
                                getPointerTy(DAG.getDataLayout()),
                                StackPtr, Offset);
      SDValue MemcpyChain = DAG.getMemcpy(
          Chain, DL, Dst, Arg, SizeNode, Alignment,
          /*isVolatile=*/false, /*AlwaysInline=*/false,
          /*CI=*/nullptr, std::nullopt,
          MachinePointerInfo::getStack(MF, VA.getLocMemOffset()),
          MachinePointerInfo());
      MemOpChains.push_back(MemcpyChain);
      continue;
    }

    // CC_Mov stamps the LocInfo for promoted narrow args; widen back to
    // i32 before storing so the slot is 4 bytes wide.
    switch (VA.getLocInfo()) {
    case CCValAssign::Full:
      break;
    case CCValAssign::AExt:
      Arg = DAG.getNode(ISD::ANY_EXTEND, DL, VA.getLocVT(), Arg);
      break;
    case CCValAssign::ZExt:
      Arg = DAG.getNode(ISD::ZERO_EXTEND, DL, VA.getLocVT(), Arg);
      break;
    case CCValAssign::SExt:
      Arg = DAG.getNode(ISD::SIGN_EXTEND, DL, VA.getLocVT(), Arg);
      break;
    default:
      report_fatal_error("Mov: unexpected LocInfo in LowerCall");
    }

    // store i32 Arg, ptr [esp + VA.getLocMemOffset()]
    SDValue Offset = DAG.getIntPtrConstant(VA.getLocMemOffset(), DL);
    SDValue Addr =
        DAG.getNode(ISD::ADD, DL, getPointerTy(DAG.getDataLayout()), StackPtr,
                    Offset);
    MemOpChains.push_back(
        DAG.getStore(Chain, DL, Arg, Addr,
                     MachinePointerInfo::getStack(MF, VA.getLocMemOffset())));
  }

  if (!MemOpChains.empty())
    Chain = DAG.getNode(ISD::TokenFactor, DL, MVT::Other, MemOpChains);

  // Translate the callee operand to a usable form. We only handle
  // GlobalAddress (direct symbol) and ExternalSymbol — function pointers
  // (indirect via register) wait for stage 6c.
  if (auto *G = dyn_cast<GlobalAddressSDNode>(Callee)) {
    Callee = DAG.getTargetGlobalAddress(G->getGlobal(), DL,
                                        getPointerTy(DAG.getDataLayout()),
                                        /*offset=*/0);
  } else if (auto *E = dyn_cast<ExternalSymbolSDNode>(Callee)) {
    Callee = DAG.getTargetExternalSymbol(
        E->getSymbol(), getPointerTy(DAG.getDataLayout()));
  } else {
    report_fatal_error(
        "Mov: indirect calls not yet supported (stage 6c will add CALL32r)");
  }

  // Build the MovISD::CALL: chain, callee, regmask, [glue].
  const auto *TRI = MF.getSubtarget().getRegisterInfo();
  const uint32_t *Mask = TRI->getCallPreservedMask(MF, CallConv);
  assert(Mask && "Mov: getCallPreservedMask must return non-null");

  SmallVector<SDValue, 4> Ops = {Chain, Callee, DAG.getRegisterMask(Mask)};

  SDVTList NodeTys = DAG.getVTList(MVT::Other, MVT::Glue);
  Chain = DAG.getNode(MovISD::CALL, DL, NodeTys, Ops);
  SDValue Glue = Chain.getValue(1);

  // CALLSEQ_END(NumBytes, 0) closes the call frame.
  Chain = DAG.getCALLSEQ_END(Chain, NumBytes, 0, Glue, DL);
  Glue = Chain.getValue(1);

  // Read back the return value (EAX) if there is one.
  SmallVector<CCValAssign, 2> RVLocs;
  CCState RetCCInfo(CallConv, /*IsVarArg=*/false, MF, RVLocs, *DAG.getContext());
  RetCCInfo.AnalyzeCallResult(Ins, RetCC_Mov);

  for (CCValAssign &VA : RVLocs) {
    assert(VA.isRegLoc() && "stage 6 RetCC always assigns to a register");
    SDValue Val = DAG.getCopyFromReg(Chain, DL, VA.getLocReg(),
                                     VA.getLocVT(), Glue);
    Chain = Val.getValue(1);
    Glue = Val.getValue(2);
    if (VA.getLocInfo() != CCValAssign::Full)
      Val = DAG.getNode(ISD::TRUNCATE, DL, VA.getValVT(), Val);
    InVals.push_back(Val);
  }
  return Chain;
}
