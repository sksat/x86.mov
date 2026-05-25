//===-- MovInstrInfo.td ----------------------------------*- tablegen -*-===//
//
// The minimum instruction set needed to lower `define i32 @main() { ret i32 0 }`:
//   - MOV32ri  mov  reg, imm32      — materialise constants and arguments
//   - MOV32rr  mov  reg, reg        — register-to-register copies (RA copies)
//   - RET                            — function epilogue + return
//
// Everything beyond this lands in later stages and additional .td files.
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// SDNodes
//===----------------------------------------------------------------------===//

// Custom return SDNode emitted by MovISelLowering::LowerReturn.
def SDT_MovRet     : SDTypeProfile<0, 0, []>;
def MovRet         : SDNode<"MovISD::RET", SDT_MovRet,
                            [SDNPHasChain, SDNPOptInGlue, SDNPVariadic]>;

//===----------------------------------------------------------------------===//
// Operand kinds
//===----------------------------------------------------------------------===//

def i32imm_op : Operand<i32>;

// Minimum addressing mode for stage 2: base register + 32-bit displacement.
// Stack-slot reads (`[esp + 4]`) need exactly this; base+index*scale shapes
// come later and will fold in as additional ComplexPattern matchers.
def MovMemOperand : Operand<i32> {
  let MIOperandInfo = (ops GPR32:$base, i32imm:$disp);
  let PrintMethod   = "printMemOperand";
}

// Match a load whose address is a FrameIndex. SelectAddrFI lives in
// MovISelDAGToDAG.cpp; it pulls the FI out and emits (base=FI, disp=0)
// so PEI's eliminateFrameIndex can rewrite the pair to (ESP, off).
def addr_fi : ComplexPattern<i32, 2, "SelectAddrFI", [frameindex]>;

//===----------------------------------------------------------------------===//
// Instruction base class
//===----------------------------------------------------------------------===//

class MovInst<dag outs, dag ins, string asmstr, list<dag> pattern>
  : Instruction {
  let Namespace        = "Mov";
  let OutOperandList   = outs;
  let InOperandList    = ins;
  let AsmString        = asmstr;
  let Pattern          = pattern;
  let Size             = 0;  // we don't emit object code yet; 0 is fine for text
}

//===----------------------------------------------------------------------===//
// MOV
//===----------------------------------------------------------------------===//

let isReMaterializable = 1, isAsCheapAsAMove = 1 in
def MOV32ri : MovInst<(outs GPR32:$dst), (ins i32imm_op:$src),
                      "mov\t$dst, $src",
                      [(set GPR32:$dst, imm:$src)]>;

let isMoveReg = 1 in
def MOV32rr : MovInst<(outs GPR32:$dst), (ins GPR32:$src),
                      "mov\t$dst, $src",
                      []>;

let mayLoad = 1 in
def MOV32rm : MovInst<(outs GPR32:$dst), (ins MovMemOperand:$src),
                      "mov\t$dst, dword ptr $src",
                      [(set GPR32:$dst, (load addr_fi:$src))]>;

//===----------------------------------------------------------------------===//
// RET
//===----------------------------------------------------------------------===//
//
// RET is currently a "mov-heavy bootstrap" placeholder — at stage 7 the
// mov-only legalization pass replaces it with a mov-driven epilogue.

let isReturn = 1, isTerminator = 1, isBarrier = 1, hasCtrlDep = 1 in
def RET : MovInst<(outs), (ins variable_ops),
                  "ret",
                  [(MovRet)]>;
