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
// Integer arithmetic + bitwise — stage 3 (mov-heavy bootstrap).
//
// x86 integer ops are 2-address (`add reg, src` is `dst = dst + src`), so
// every binop here ties `$src1` to `$dst`. Register allocation honours the
// tie by coalescing the two virtual registers; without it RA would freely
// pick distinct physical regs for `$src1` and `$dst` and the resulting asm
// would be wrong.
//
// Shift forms are immediate-only at stage 3; reg-shift hits the x86 `CL`
// register-class constraint and lives in stage 3.5.
//
// Mov-only legalization (stage 7+) will replace these with mov-table
// lookups. Don't add commutative simplifications or addressing-mode
// folds here that the legalization pass would have to unpick.
//===----------------------------------------------------------------------===//

class BinOpRR<string OpStr, SDNode OpNode, bit Commutable = 0>
  : MovInst<(outs GPR32:$dst), (ins GPR32:$src1, GPR32:$src2),
            !strconcat(OpStr, "\t$dst, $src2"),
            [(set GPR32:$dst, (OpNode GPR32:$src1, GPR32:$src2))]> {
  let Constraints = "$src1 = $dst";
  let isCommutable = Commutable;
}

class BinOpRI<string OpStr, SDNode OpNode>
  : MovInst<(outs GPR32:$dst), (ins GPR32:$src1, i32imm_op:$src2),
            !strconcat(OpStr, "\t$dst, $src2"),
            [(set GPR32:$dst, (OpNode GPR32:$src1, imm:$src2))]> {
  let Constraints = "$src1 = $dst";
}

class ShiftRI<string OpStr, SDNode OpNode>
  : MovInst<(outs GPR32:$dst), (ins GPR32:$src1, i32imm_op:$amt),
            !strconcat(OpStr, "\t$dst, $amt"),
            [(set GPR32:$dst, (OpNode GPR32:$src1, (i32 imm:$amt)))]> {
  let Constraints = "$src1 = $dst";
}

def ADD32rr : BinOpRR<"add", add, /*Commutable=*/1>;
def ADD32ri : BinOpRI<"add", add>;
def SUB32rr : BinOpRR<"sub", sub>;
def SUB32ri : BinOpRI<"sub", sub>;
def AND32rr : BinOpRR<"and", and, /*Commutable=*/1>;
def AND32ri : BinOpRI<"and", and>;
def OR32rr  : BinOpRR<"or",  or,  /*Commutable=*/1>;
def OR32ri  : BinOpRI<"or",  or>;
def XOR32rr : BinOpRR<"xor", xor, /*Commutable=*/1>;
def XOR32ri : BinOpRI<"xor", xor>;

def SHL32ri : ShiftRI<"shl", shl>;
def SHR32ri : ShiftRI<"shr", srl>;
def SAR32ri : ShiftRI<"sar", sra>;

// Variable-amount shifts. x86 constrains the count to CL; we expose the
// constraint via `Uses = [ECX]` (the register-allocator-visible side) and
// hardcode `cl` in the AsmString (the printer side). Patternless on
// purpose: MovDAGToDAGISel::Select inserts the `mov ecx, <amt>` CopyToReg
// + glue ahead of these — TableGen patterns can't express "copy this
// operand into a specific physreg first".
class ShiftRCL<string OpStr>
  : MovInst<(outs GPR32:$dst), (ins GPR32:$src1),
            !strconcat(OpStr, "\t$dst, cl"),
            []> {
  let Constraints = "$src1 = $dst";
  let Uses = [ECX];
}

def SHL32rCL : ShiftRCL<"shl">;
def SHR32rCL : ShiftRCL<"shr">;
def SAR32rCL : ShiftRCL<"sar">;

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
