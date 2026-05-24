//===-- Mov.td - Top-level TableGen description -----------*- tablegen -*-===//
//
// Top-level declaration of the `Mov` target. Brings in the register set,
// instruction set, and calling-convention descriptions and ties them to a
// target singleton (`def Mov`).
//
//===----------------------------------------------------------------------===//

include "llvm/Target/Target.td"

include "MovRegisterInfo.td"
include "MovCallingConv.td"
include "MovInstrInfo.td"

def MovInstrInfo : InstrInfo;

// LLVM 22+ requires targets to remap PointerLikeRegClass operands on the
// shared pseudo instructions (LOAD_STACK_GUARD, PREALLOCATED_ARG, the
// PATCHABLE_*_EVENT_CALL pair). Stage 0 doesn't actually generate any of
// these, but TableGen still asks us to declare the substitution — point
// them at GPR32 since that's our only pointer-shaped class right now.
defm : RemapAllTargetPseudoPointerOperands<GPR32>;

// The asm writer used by `MovAsmPrinter`. `AsmString` on each Instruction
// definition supplies the text — TableGen generates `MovGenAsmWriter.inc`
// which the printer includes.
def MovAsmWriter : AsmWriter {
  string AsmWriterClassName  = "InstPrinter";
  int PassSubtarget          = 0;
  int Variant                = 0;
}

def Mov : Target {
  let InstructionSet   = MovInstrInfo;
  let AssemblyWriters  = [MovAsmWriter];
}
