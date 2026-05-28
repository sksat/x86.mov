//===-- MovInstPrinter.cpp ------------------------------------------------===//
#include "MCTargetDesc/MovInstPrinter.h"
#include "llvm/MC/MCAsmInfo.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCInst.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

#define PRINT_ALIAS_INSTR
#include "MovGenAsmWriter.inc"

void MovInstPrinter::printInst(const MCInst *MI, uint64_t Address,
                               StringRef Annot, const MCSubtargetInfo &STI,
                               raw_ostream &O) {
  printInstruction(MI, Address, O);
  printAnnotation(O, Annot);
}

void MovInstPrinter::printRegName(raw_ostream &O, MCRegister Reg) {
  O << getRegisterName(Reg);
}

void MovInstPrinter::printOperand(const MCInst *MI, unsigned OpNo,
                                  raw_ostream &O) {
  const MCOperand &Op = MI->getOperand(OpNo);
  if (Op.isReg()) {
    printRegName(O, Op.getReg());
  } else if (Op.isImm()) {
    O << Op.getImm();
  } else if (Op.isExpr()) {
    MAI.printExpr(O, *Op.getExpr());
  } else {
    llvm_unreachable("unexpected MCOperand kind");
  }
}

void MovInstPrinter::printMemOperand(const MCInst *MI, unsigned OpNo,
                                     raw_ostream &O) {
  const MCOperand &Base = MI->getOperand(OpNo);
  const MCOperand &Disp = MI->getOperand(OpNo + 1);
  O << '[';
  bool HasBase = Base.isReg() && Base.getReg() != 0;
  if (HasBase)
    printRegName(O, Base.getReg());
  if (Disp.isImm()) {
    int64_t V = Disp.getImm();
    if (!HasBase) {
      O << V;
    } else if (V > 0) {
      O << " + " << V;
    } else if (V < 0) {
      O << " - " << -V;
    }
    // V == 0 with a base: omit the displacement entirely.
  }
  O << ']';
}

void MovInstPrinter::printIdxMemOperand(const MCInst *MI, unsigned OpNo,
                                        raw_ostream &O) {
  const MCOperand &Base = MI->getOperand(OpNo);
  const MCOperand &Index = MI->getOperand(OpNo + 1);
  if (!Base.isExpr())
    llvm_unreachable("MovIdxMemOperand base must be an MCExpr (table symbol)");
  if (!Index.isReg() || Index.getReg() == 0)
    llvm_unreachable("MovIdxMemOperand index must be a non-zero register");
  O << '[';
  MAI.printExpr(O, *Base.getExpr());
  O << " + ";
  printRegName(O, Index.getReg());
  O << ']';
}
