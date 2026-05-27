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

// Direct cdecl call: a single operand carrying the callee's symbol. Variadic
// chain operands carry the register-mask, ESP def/use, and CopyToReg chain
// that LowerCall builds up. Selection in MovISelDAGToDAG emits CALL32d.
def SDT_MovCall    : SDTypeProfile<0, 1, [SDTCisVT<0, iPTR>]>;
def MovCall        : SDNode<"MovISD::CALL", SDT_MovCall,
                            [SDNPHasChain, SDNPOptInGlue, SDNPOutGlue,
                             SDNPVariadic]>;

// Call-frame setup / teardown pseudos. PEI sees these around every CALL,
// and MovFrameLowering::eliminateCallFramePseudoInstr turns them into the
// real SP adjustments (`sub esp, N` / `add esp, N`). The opcodes must be
// passed to MovGenInstrInfo's ctor (CFSetupOpcode / CFDestroyOpcode), so
// the InstrInfo<-> CodeGen wiring knows which opcodes to use.
def SDT_MovCallSeqStart : SDCallSeqStart<[SDTCisVT<0, i32>, SDTCisVT<1, i32>]>;
def SDT_MovCallSeqEnd   : SDCallSeqEnd<[SDTCisVT<0, i32>, SDTCisVT<1, i32>]>;
def MovCallSeqStart : SDNode<"ISD::CALLSEQ_START", SDT_MovCallSeqStart,
                             [SDNPHasChain, SDNPOutGlue]>;
def MovCallSeqEnd   : SDNode<"ISD::CALLSEQ_END",   SDT_MovCallSeqEnd,
                             [SDNPHasChain, SDNPOptInGlue, SDNPOutGlue]>;

//===----------------------------------------------------------------------===//
// Operand kinds
//===----------------------------------------------------------------------===//

def i32imm_op : Operand<i32>;

// 8-bit immediate operand for stage 7-prep's MOV8ri.
def i8imm_op : Operand<i8>;

// Branch-target operand for JMP / Jcc. OtherVT is the LLVM convention for
// "this is a code-pointer-shaped operand; print whatever the printer
// decides to call it"; AsmPrinter::lower turns the MO_MachineBasicBlock
// into an MCSymbolRef so `as` resolves the label.
def brtarget : Operand<OtherVT> {
  let OperandType = "OPERAND_PCREL";
}

// Call-target operand for CALL32d: a global symbol. AsmPrinter::lower
// translates MO_GlobalAddress / MO_ExternalSymbol into an MCSymbolRef
// expression (with optional offset folded in).
def calltarget : Operand<iPTR> {
  let OperandType = "OPERAND_PCREL";
}

// Minimum addressing mode for stage 2: base register + 32-bit displacement.
// Stack-slot reads (`[esp + 4]`) need exactly this; base+index*scale shapes
// come later and will fold in as additional ComplexPattern matchers.
def MovMemOperand : Operand<i32> {
  let MIOperandInfo = (ops GPR32:$base, i32imm:$disp);
  let PrintMethod   = "printMemOperand";
}

// Stage 7-prep-2b: symbol-typed operand for the base of a byte-table
// lookup. Distinct from `calltarget` (which is OPERAND_PCREL for `call
// <sym>`) — table lookups use absolute (R_386_32) relocations and the
// printer emits the symbol inside `[<sym> + <reg>]`, not as a branch
// target. The MO is always MO_ExternalSymbol or MO_GlobalAddress lowered
// to an MCExpr by MovAsmPrinter::lower; printIdxMemOperand asserts that.
def tablesym : Operand<iPTR>;

// Stage 7-prep-2b: `[<table-symbol> + <index_reg>]` addressing mode used
// by MovOnlyLegalize for byte-add table lookups. Held separately from
// MovMemOperand so the existing 32-bit memory ops are unaffected. No
// ISel ComplexPattern — MOV8rm_idx is built directly by the legalize
// pass via BuildMI; SelectAddr is never invoked for it. The index is
// constrained to GPR32_NOSP so the legalize pass can't accidentally use
// ESP/EBP as an index (the byte we feed in is conceptually CL/AL/etc.
// but is named as its parent ECX/EAX register in the printed asm).
def MovIdxMemOperand : Operand<i32> {
  let MIOperandInfo = (ops tablesym:$base, GPR32_NOSP:$index);
  let PrintMethod   = "printIdxMemOperand";
}

// Address selector for memory ops. Stage 6a generalises beyond
// frame-index-only addresses: outgoing-arg stores arrive as
// `(add (CopyFromReg ESP), imm)`, which is a register-base + displacement.
//
// SelectAddr (in MovISelDAGToDAG.cpp) handles three shapes:
//   1. plain FrameIndex             → (TargetFrameIndex, 0)
//   2. ADD(FrameIndex, imm)         → (TargetFrameIndex, imm)
//   3. ADD(reg, imm)                → (reg, imm)
//   4. any other reg                → (reg, 0)
// Cases (1)/(2) feed eliminateFrameIndex (EBP-relative resolution); cases
// (3)/(4) bypass it and emit straight register-base addresses.
def addr : ComplexPattern<i32, 2, "SelectAddr",
                          [frameindex, add]>;

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
                      [(set GPR32:$dst, (load addr:$src))]>;

// MOV32mr — store form. Used by the spill machinery (storeRegToStackSlot
// in MovInstrInfo.cpp) and, at stage 4c+, by `store i32 ..., ptr ...`
// patterns. Stage 4b adds the C++ side; the DAG pattern grows in 4c.
let mayStore = 1 in
def MOV32mr : MovInst<(outs), (ins MovMemOperand:$dst, GPR32:$src),
                      "mov\tdword ptr $dst, $src",
                      [(store GPR32:$src, addr:$dst)]>;

// MOV32mi — store an i32 immediate (or 32-bit symbol expression) into
// memory. No DAG pattern: MovOnlyLegalize uses this from stage 7c1
// onward to write a target MBB's code pointer into the dispatcher
// `next_pc` slot without needing a scratch GPR. Operand 1 accepts
// MO_Immediate, MO_MachineBasicBlock, and MO_GlobalAddress — all
// lowered to MCExpr by MovAsmPrinter::lower.
//
// The asmstr uses the `offset` keyword on the immediate operand. GAS
// Intel syntax requires it for label/symbol immediates in mem-imm mov
// (`mov dword ptr [...], .Llabel` is rejected; `offset .Llabel` is
// the unambiguous form for "address of symbol"). For numeric
// immediates `offset N` evaluates to N, so this is safe for both
// shapes.
let mayStore = 1, isCodeGenOnly = 1 in
def MOV32mi : MovInst<(outs), (ins MovMemOperand:$dst, i32imm_op:$src),
                      "mov\tdword ptr $dst, offset $src", []>;

// 8-bit MOV family — stage 7-prep. No DAG patterns: these instructions
// are reserved for MovOnlyLegalize (post-RA) to build mov-only
// table-lookup chains. The MOV{8rm,8mr,8rr,8ri} forms mirror the
// existing 32-bit set so the legalize pass can emit them via BuildMI.
//
// Note: the GR8 register class (AL/CL/DL/BL) is a sub_8bit of the
// GPR32 set, so RA correctly understands that using CL overlaps with
// ECX. Stage 7a1 will exploit this to spill the parent reg before
// using its low byte for table-lookup scratch.

let mayLoad = 1 in
def MOV8rm : MovInst<(outs GR8:$dst), (ins MovMemOperand:$src),
                     "mov\t$dst, byte ptr $src", []>;

let mayStore = 1 in
def MOV8mr : MovInst<(outs), (ins MovMemOperand:$dst, GR8:$src),
                     "mov\tbyte ptr $dst, $src", []>;

let isMoveReg = 1 in
def MOV8rr : MovInst<(outs GR8:$dst), (ins GR8:$src),
                     "mov\t$dst, $src", []>;

let isReMaterializable = 1, isAsCheapAsAMove = 1 in
def MOV8ri : MovInst<(outs GR8:$dst), (ins i8imm_op:$src),
                     "mov\t$dst, $src", []>;

// Stage 7-prep-2b: indexed byte load — `mov <dst-byte>, byte ptr
// [<table-symbol> + <index_reg>]`. Legalize-only, no DAG pattern; the
// MovOnlyLegalize pass builds these directly via BuildMI with
// `.addExternalSymbol("__mov_add8_sum_table")` + `.addReg(IdxReg)`. The
// index register is named as its full 32-bit parent in the printed asm
// (the table is indexed by `cin*65536 + a*256 + b`, where `a` is held
// in CL but written as ECX in the asm), so the index slot is
// GPR32_NOSP, not GR8.
let mayLoad = 1, isCodeGenOnly = 1 in
def MOV8rm_idx : MovInst<(outs GR8:$dst), (ins MovIdxMemOperand:$src),
                         "mov\t$dst, byte ptr $src", []>;

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
// PUSH / POP — used by emitPrologue/emitEpilogue (stage 4a) to save and
// restore EBP for the frame pointer. No DAG patterns: these are
// target-only, emitted directly via BuildMI from FrameLowering. The
// `Defs/Uses [ESP]` make ESP's implicit modification visible to RA.
//===----------------------------------------------------------------------===//

let Defs = [ESP], Uses = [ESP], mayStore = 1 in
def PUSH32r : MovInst<(outs), (ins GPR32:$src),
                      "push\t$src", []>;

let Defs = [ESP], Uses = [ESP], mayLoad = 1 in
def POP32r  : MovInst<(outs GPR32:$dst), (ins),
                      "pop\t$dst", []>;

//===----------------------------------------------------------------------===//
// CALL / CALLSEQ_START / CALLSEQ_END  (stage 6a)
//
// CALLSEQ_START/END bracket each call so PEI can track ESP movement that
// the caller's argument-pushing introduces. eliminateCallFramePseudoInstr
// in MovFrameLowering rewrites them into the real `sub esp, N` / `add esp, N`
// adjustments at codegen-finalisation time.
//
// CALL32d is the direct-call form. Operand 0 is the callee symbol;
// additional operands (regmask, implicit ESP/EAX uses/defs) get attached
// by LowerCall + selection. isCall = 1 makes the regmask / call-clobber
// machinery kick in. We model the cdecl preserves via the EAX-clobbering
// Defs list (caller-saved are ECX, EDX, EAX; selection passes the explicit
// regmask too).
//===----------------------------------------------------------------------===//

let Defs = [ESP], Uses = [ESP], hasSideEffects = 0,
    isCodeGenOnly = 1, mayLoad = 0, mayStore = 0 in {
def ADJCALLSTACKDOWN : MovInst<(outs), (ins i32imm_op:$amt1, i32imm_op:$amt2),
                               "# ADJCALLSTACKDOWN $amt1",
                               [(MovCallSeqStart timm:$amt1, timm:$amt2)]>;
def ADJCALLSTACKUP   : MovInst<(outs), (ins i32imm_op:$amt1, i32imm_op:$amt2),
                               "# ADJCALLSTACKUP $amt1",
                               [(MovCallSeqEnd timm:$amt1, timm:$amt2)]>;
}

let isCall = 1, Defs = [EAX, ECX, EDX, EFLAGS], Uses = [ESP],
    mayLoad = 1, mayStore = 1, hasSideEffects = 1 in
def CALL32d : MovInst<(outs), (ins calltarget:$dst),
                      "call\t$dst", []>;

//===----------------------------------------------------------------------===//
// CMP — sets EFLAGS for the following Jcc. Patternless: selection (stage
// 5b) pairs them with a glued Jcc rather than relying on TableGen
// SDNode-pattern matching for the CMP→Jcc dependence.
//===----------------------------------------------------------------------===//

let Defs = [EFLAGS], hasSideEffects = 0 in {
def CMP32rr : MovInst<(outs), (ins GPR32:$src1, GPR32:$src2),
                      "cmp\t$src1, $src2", []>;
def CMP32ri : MovInst<(outs), (ins GPR32:$src1, i32imm_op:$src2),
                      "cmp\t$src1, $src2", []>;
}

//===----------------------------------------------------------------------===//
// JMP / Jcc — unconditional and conditional branches. Operand is a
// MachineBasicBlock; AsmPrinter::lower routes MO_MachineBasicBlock to an
// MCSymbolRef expression so `as` resolves the label.
//
// Mapping LLVM ICmp predicate → x86 mnemonic (used in MovISelDAGToDAG):
//   EQ  → je       NE  → jne
//   SLT → jl       SGT → jg       SLE → jle       SGE → jge
//   ULT → jb       UGT → ja       ULE → jbe       UGE → jae
//
// One opcode per predicate (no abstract Jcc<predicate> pseudo) — keeps
// the printer trivial and the MIR readable. Stage-7 mov-only
// legalization replaces all of these with mov-driven branchless idioms.
//===----------------------------------------------------------------------===//

let isBranch = 1, isTerminator = 1, isBarrier = 1 in
def JMP : MovInst<(outs), (ins brtarget:$dst),
                  "jmp\t$dst", [(br bb:$dst)]>;

class JccInst<string OpStr>
  : MovInst<(outs), (ins brtarget:$dst),
            !strconcat(OpStr, "\t$dst"), []> {
  let isBranch     = 1;
  let isTerminator = 1;
  let Uses         = [EFLAGS];
}

def JE  : JccInst<"je">;
def JNE : JccInst<"jne">;
def JL  : JccInst<"jl">;
def JG  : JccInst<"jg">;
def JLE : JccInst<"jle">;
def JGE : JccInst<"jge">;
def JB  : JccInst<"jb">;
def JA  : JccInst<"ja">;
def JBE : JccInst<"jbe">;
def JAE : JccInst<"jae">;

// Stage 7c0 — indirect jump through a memory operand. Reads a 32-bit
// code pointer from `[base + disp]` and jumps to it. Used by the
// branchless-dispatcher CFG transformation: from stage 7c1 onwards,
// the rewrites of JMP/Jcc/fallthrough store a target BB's address
// into a per-function `next_pc` scratch slot and end with a
// `jmp dword ptr [ebp + next_pc_disp]` that reads + dispatches.
//
// codegen-only — no DAG pattern. MovOnlyLegalize builds these via
// BuildMI from the dispatcher MBB it constructs per function.
let isBranch = 1, isTerminator = 1, isBarrier = 1,
    isIndirectBranch = 1, mayLoad = 1, isCodeGenOnly = 1 in
def JMP32m : MovInst<(outs), (ins MovMemOperand:$tgt),
                     "jmp\tdword ptr $tgt", []>;

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
