//===-- MovInstPrinter.h ----------------------------------------*- C++ -*-===//
#pragma once

#include "llvm/MC/MCInstPrinter.h"

namespace llvm {
// TableGen produces `MovGenAsmWriter.inc` from the AsmString fields in
// MovInstrInfo.td; this thin subclass plugs it into the MCInstPrinter
// machinery the streamer expects.
class MovInstPrinter : public MCInstPrinter {
public:
  MovInstPrinter(const MCAsmInfo &MAI, const MCInstrInfo &MII,
                 const MCRegisterInfo &MRI)
      : MCInstPrinter(MAI, MII, MRI) {}

  void printInst(const MCInst *MI, uint64_t Address, StringRef Annot,
                 const MCSubtargetInfo &STI, raw_ostream &O) override;

  // Generated entry points from MovGenAsmWriter.inc:
  void printInstruction(const MCInst *MI, uint64_t Address, raw_ostream &O);
  std::pair<const char *, uint64_t> getMnemonic(const MCInst &MI) const override;
  bool printAliasInstr(const MCInst *MI, uint64_t Address, raw_ostream &OS);
  static const char *getRegisterName(MCRegister Reg);

  void printRegName(raw_ostream &O, MCRegister Reg) override;
  void printOperand(const MCInst *MI, unsigned OpNo, raw_ostream &O);
};
} // namespace llvm
