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
#include "MovISelLowering.h"
#include "MovSubtarget.h"
#include "MovTargetMachine.h"
#include "llvm/CodeGen/MachineBasicBlock.h"
#include "llvm/CodeGen/SelectionDAG.h"
#include "llvm/CodeGen/SelectionDAGISel.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/ErrorHandling.h"

#define DEBUG_TYPE "mov-isel"

using namespace llvm;

namespace {
// Map an LLVM CondCode to the matching x86-style Jcc opcode.
unsigned getJccForCondCode(ISD::CondCode CC) {
  switch (CC) {
  case ISD::SETEQ:  return Mov::JE;
  case ISD::SETNE:  return Mov::JNE;
  case ISD::SETLT:  return Mov::JL;
  case ISD::SETGT:  return Mov::JG;
  case ISD::SETLE:  return Mov::JLE;
  case ISD::SETGE:  return Mov::JGE;
  case ISD::SETULT: return Mov::JB;
  case ISD::SETUGT: return Mov::JA;
  case ISD::SETULE: return Mov::JBE;
  case ISD::SETUGE: return Mov::JAE;
  default: break;
  }
  llvm_unreachable("Mov: unsupported CondCode in BR_CC selection");
}
} // namespace

namespace {
class MovDAGToDAGISel : public SelectionDAGISel {
public:
  MovDAGToDAGISel(MovTargetMachine &TM, CodeGenOptLevel OptLevel)
      : SelectionDAGISel(TM, OptLevel) {}

  void Select(SDNode *Node) override;

  // Address-mode selector for MovInstrInfo.td's `addr` ComplexPattern.
  // Matches plain FrameIndex (stage 2/4 form), FrameIndex + imm
  // displacement (stage 4 spill/local), and reg + imm displacement
  // (stage 6a outgoing-arg stores via ESP).
  bool SelectAddr(SDValue Addr, SDValue &Base, SDValue &Disp);

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
  // Bare FrameIndex used as an i32 value (i.e. *not* as the base of a
  // memory operand — that case is handled by SelectAddr inside the
  // load/store ComplexPattern). Examples: a callee that takes a
  // pointer arg flowing through registers, an `&local` materialized
  // into a vreg before the GEP. The TableGen-generated SelectCode has
  // no built-in pattern for this, so we lower it manually to
  //     LEA32r dst, FrameIndex, 0
  // PEI's eliminateFrameIndex resolves the FrameIndex operand to
  // (EBP, disp) using the same logic as for load/store ops, and stage
  // 7 mov-only legalization rewrites LEA32r into `mov dst, ebp` +
  // byte-chain ADD32ri disp.
  if (Node->getOpcode() == ISD::FrameIndex) {
    SDLoc DL(Node);
    const EVT PtrTy = TLI->getPointerTy(CurDAG->getDataLayout());
    const int FI = cast<FrameIndexSDNode>(Node)->getIndex();
    SDValue TFI  = CurDAG->getTargetFrameIndex(FI, PtrTy);
    SDValue Zero = CurDAG->getTargetConstant(0, DL, MVT::i32);
    SDNode *Lea  = CurDAG->getMachineNode(Mov::LEA32r, DL, MVT::i32,
                                          {TFI, Zero});
    ReplaceNode(Node, Lea);
    return;
  }

  // Global / external / blockaddress symbol → MOV32ri.
  //
  // ISD::GlobalAddress arrives un-lowered from DAG building because we
  // haven't marked it Custom in LowerOperation. The TableGen-generated
  // SelectCode only matches the *target* form (tglobaladdr), so we
  // convert here and emit MOV32ri ourselves. MOV32ri's asmstr uses
  // `offset $src`, which produces `mov reg, offset <sym>` — the
  // unambiguous GAS Intel-syntax form for materializing a symbol's
  // address. Same handling for ExternalSymbol and BlockAddress.
  if (Node->getOpcode() == ISD::GlobalAddress) {
    SDLoc DL(Node);
    auto *GA = cast<GlobalAddressSDNode>(Node);
    SDValue Sym = CurDAG->getTargetGlobalAddress(
        GA->getGlobal(), DL, MVT::i32, GA->getOffset(), GA->getTargetFlags());
    SDNode *MI = CurDAG->getMachineNode(Mov::MOV32ri, DL, MVT::i32, Sym);
    ReplaceNode(Node, MI);
    return;
  }
  if (Node->getOpcode() == ISD::ExternalSymbol) {
    SDLoc DL(Node);
    auto *ES = cast<ExternalSymbolSDNode>(Node);
    SDValue Sym = CurDAG->getTargetExternalSymbol(
        ES->getSymbol(), MVT::i32, ES->getTargetFlags());
    SDNode *MI = CurDAG->getMachineNode(Mov::MOV32ri, DL, MVT::i32, Sym);
    ReplaceNode(Node, MI);
    return;
  }
  if (Node->getOpcode() == ISD::BlockAddress) {
    SDLoc DL(Node);
    auto *BA = cast<BlockAddressSDNode>(Node);
    SDValue Sym = CurDAG->getTargetBlockAddress(
        BA->getBlockAddress(), MVT::i32, BA->getOffset(),
        BA->getTargetFlags());
    SDNode *MI = CurDAG->getMachineNode(Mov::MOV32ri, DL, MVT::i32, Sym);
    ReplaceNode(Node, MI);
    return;
  }

  // MovISD::CALL: emit
  //     CALL32d <callee_symbol>     ; Uses=[ESP], Defs=[EAX/ECX/EDX/EFLAGS]
  //
  // The original SDNode operands are (Chain, Callee, RegMask[, ...InGlue]).
  // We rebuild the machine-node operand list as
  //     (Callee, RegMask, Chain[, ...InGlue])
  // — Callee first because it's our only explicit input on CALL32d, then
  // the regmask + the chain/glue tail as implicit attachments.
  if (Node->getOpcode() == MovISD::CALL) {
    SDLoc DL(Node);
    SDValue Chain  = Node->getOperand(0);
    SDValue Callee = Node->getOperand(1);

    SmallVector<SDValue, 8> Ops;
    Ops.push_back(Callee);
    // Forward regmask + any other tail operands (chain glue from earlier
    // CopyToReg sequences) verbatim.
    for (unsigned i = 2, e = Node->getNumOperands(); i != e; ++i)
      Ops.push_back(Node->getOperand(i));
    Ops.push_back(Chain);

    SDVTList NodeTys = CurDAG->getVTList(MVT::Other, MVT::Glue);
    SDNode *MICall = CurDAG->getMachineNode(Mov::CALL32d, DL, NodeTys, Ops);
    ReplaceNode(Node, MICall);
    return;
  }

  // MovISD::BR_CC: emit
  //     CMP32r{r,i} LHS, RHS    ; Defs = [EFLAGS]   (glue1)
  //     Jcc<CC> target          ; Uses = [EFLAGS]   (consumes glue1)
  // Glue keeps the pair adjacent so the scheduler can't interleave a
  // flag-clobbering instruction between them — Defs/Uses alone would
  // not pin the ordering tightly enough (codex's stage-5 design note).
  if (Node->getOpcode() == MovISD::BR_CC) {
    SDLoc DL(Node);
    SDValue Chain  = Node->getOperand(0);
    ISD::CondCode CC =
        cast<CondCodeSDNode>(Node->getOperand(1))->get();
    SDValue LHS    = Node->getOperand(2);
    SDValue RHS    = Node->getOperand(3);
    SDValue Target = Node->getOperand(4);

    // x86 CMP only has a `reg, imm` form (CMP32ri) — not `imm, reg`. If
    // the user wrote `icmp eq 42, %x` and DAGCombine didn't canonicalise,
    // the constant ends up on LHS and we'd otherwise pick CMP32rr with a
    // ConstantSDNode in the first GPR32 slot — crash. Swap operands and
    // flip the predicate to keep semantics. (Caught by codex's stage-5b
    // review of 1eeb8a0.)
    if (isa<ConstantSDNode>(LHS) && !isa<ConstantSDNode>(RHS)) {
      std::swap(LHS, RHS);
      CC = ISD::getSetCCSwappedOperands(CC);
    }

    SDNode *Cmp;
    if (auto *CRHS = dyn_cast<ConstantSDNode>(RHS)) {
      // CMP32ri  lhs, imm
      SDValue Imm = CurDAG->getTargetConstant(
          CRHS->getSExtValue(), DL, MVT::i32);
      Cmp = CurDAG->getMachineNode(
          Mov::CMP32ri, DL, MVT::Glue, {LHS, Imm});
    } else {
      // CMP32rr  lhs, rhs
      Cmp = CurDAG->getMachineNode(
          Mov::CMP32rr, DL, MVT::Glue, {LHS, RHS});
    }

    SDValue Glue = SDValue(Cmp, 0);
    SDNode *Jcc = CurDAG->getMachineNode(
        getJccForCondCode(CC), DL, MVT::Other,
        {Target, Chain, Glue});
    ReplaceNode(Node, Jcc);
    return;
  }

  // Variable-amount shifts: x86 requires the count in CL, so before falling
  // back to TableGen patterns (which only know `shift reg, imm`) we
  // intercept (shl/srl/sra GPR32, GPR32) and emit
  //
  //     %ecx = COPY <amt>
  //     %dst = SHL32rCL %src1           ; Uses=[ECX]
  //
  // The CopyToReg's glue is hung off the shift instruction so the register
  // scheduler keeps them adjacent. We only intercept the reg-amount form;
  // imm-amount keeps using SHL32ri via the TableGen pattern.
  unsigned ShiftOp = 0;
  switch (Node->getOpcode()) {
  case ISD::SHL: ShiftOp = Mov::SHL32rCL; break;
  case ISD::SRL: ShiftOp = Mov::SHR32rCL; break;
  case ISD::SRA: ShiftOp = Mov::SAR32rCL; break;
  default:       break;
  }
  if (ShiftOp && Node->getValueType(0) == MVT::i32 &&
      !isa<ConstantSDNode>(Node->getOperand(1))) {
    SDLoc DL(Node);
    SDValue Src = Node->getOperand(0);
    SDValue Amt = Node->getOperand(1);

    SDValue Chain = CurDAG->getEntryNode();
    SDValue Copy  = CurDAG->getCopyToReg(Chain, DL, Mov::ECX, Amt, SDValue());
    SDValue Glue  = Copy.getValue(1);

    SDValue Ops[] = { Src, Glue };
    SDNode *Shift = CurDAG->getMachineNode(
        ShiftOp, DL, CurDAG->getVTList(MVT::i32, MVT::Glue), Ops);
    ReplaceNode(Node, Shift);
    return;
  }

  SelectCode(Node);
}

bool MovDAGToDAGISel::SelectAddr(SDValue Addr, SDValue &Base, SDValue &Disp) {
  const SDLoc DL(Addr);
  const EVT PtrTy = TLI->getPointerTy(CurDAG->getDataLayout());

  // Case 1: plain FrameIndex.
  if (auto *FIN = dyn_cast<FrameIndexSDNode>(Addr)) {
    Base = CurDAG->getTargetFrameIndex(FIN->getIndex(), PtrTy);
    Disp = CurDAG->getTargetConstant(0, DL, MVT::i32);
    return true;
  }

  // Case 2/3: ADD(base, imm) or OR(base, imm). DAGCombine canonicalises
  // constants to the RHS, so we only check that side. Base may itself
  // be a FrameIndex (alloca + GEP-style offset) — handled inline.
  //
  // The OR shape arises when the optimiser knows the low N bits of
  // `base` are zero — e.g. an aligned FrameIndex with a small const
  // offset added — and `add(base, K) == or(base, K)` for K that fits
  // in the zero-bits. Treating OR-by-constant identically to ADD
  // here is exactly what eliminateFrameIndex needs (it only cares
  // about the (FI, disp) pair the operand carries).
  if (Addr.getOpcode() == ISD::ADD || Addr.getOpcode() == ISD::OR) {
    SDValue LHS = Addr.getOperand(0);
    SDValue RHS = Addr.getOperand(1);
    if (auto *C = dyn_cast<ConstantSDNode>(RHS)) {
      const int64_t Off = C->getSExtValue();
      Disp = CurDAG->getTargetConstant(Off, DL, MVT::i32);
      if (auto *FIN = dyn_cast<FrameIndexSDNode>(LHS)) {
        Base = CurDAG->getTargetFrameIndex(FIN->getIndex(), PtrTy);
      } else {
        Base = LHS;
      }
      return true;
    }
  }

  // Case 4: bare register (e.g. CopyFromReg ESP at the head of an
  // outgoing-arg store-list). disp = 0.
  Base = Addr;
  Disp = CurDAG->getTargetConstant(0, DL, MVT::i32);
  return true;
}

FunctionPass *llvm::createMovISelDag(MovTargetMachine &TM,
                                     CodeGenOptLevel OptLevel) {
  return new MovDAGToDAGISelLegacy(TM, OptLevel);
}
