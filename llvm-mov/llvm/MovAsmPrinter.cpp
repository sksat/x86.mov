//===-- MovAsmPrinter.cpp -------------------------------------------------===//
//
// AsmPrinter for the Mov target. MachineInstr → MCInst → text via the
// MCInstPrinter wired up in MovMCTargetDesc.cpp. Almost no per-instruction
// logic is needed because TableGen patterns already produce the right MCInst
// shape.
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/MovInstPrinter.h"
#include "MCTargetDesc/MovMCTargetDesc.h"
#include "MovTargetMachine.h"
#include "TargetInfo/MovTargetInfo.h"
#include "llvm/CodeGen/AsmPrinter.h"
#include "llvm/CodeGen/MachineInstr.h"
#include "llvm/CodeGen/MachineOperand.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCInstBuilder.h"
#include "llvm/MC/MCStreamer.h"
#include "llvm/MC/MCSymbol.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

namespace {
class MovAsmPrinter : public AsmPrinter {
public:
  explicit MovAsmPrinter(TargetMachine &TM,
                         std::unique_ptr<MCStreamer> Streamer)
      : AsmPrinter(TM, std::move(Streamer)) {}

  StringRef getPassName() const override { return "Mov Assembly Printer"; }

  void emitInstruction(const MachineInstr *MI) override;

  // Emit `.intel_syntax noprefix` once at the top of the file. Output is
  // therefore directly accepted by `as --32`.
  void emitStartOfAsmFile(Module & /*M*/) override {
    OutStreamer->emitRawText(StringRef(".intel_syntax noprefix"));
  }

private:
  void lower(const MachineInstr *MI, MCInst &OutMI) const;
};
} // namespace

void MovAsmPrinter::lower(const MachineInstr *MI, MCInst &OutMI) const {
  OutMI.setOpcode(MI->getOpcode());
  for (const MachineOperand &MO : MI->operands()) {
    MCOperand MCOp;
    switch (MO.getType()) {
    case MachineOperand::MO_Register:
      if (MO.isImplicit())
        continue;
      MCOp = MCOperand::createReg(MO.getReg());
      break;
    case MachineOperand::MO_Immediate:
      MCOp = MCOperand::createImm(MO.getImm());
      break;
    case MachineOperand::MO_MachineBasicBlock:
      // Branch targets — `jcc target_block` / `jmp target_block`. The
      // `.Lfunc_endN` machinery in AsmPrinter already names the blocks;
      // we just wrap the MBB's symbol as an MCExpr.
      MCOp = MCOperand::createExpr(MCSymbolRefExpr::create(
          MO.getMBB()->getSymbol(), OutContext));
      break;
    case MachineOperand::MO_GlobalAddress:
      // Stage 5a doesn't emit any calls yet, but adding the case now
      // keeps lower() honest for stage 6: `call <global>` is the next
      // thing that lands here.
      MCOp = MCOperand::createExpr(MCSymbolRefExpr::create(
          getSymbol(MO.getGlobal()), OutContext));
      break;
    case MachineOperand::MO_ExternalSymbol:
      MCOp = MCOperand::createExpr(MCSymbolRefExpr::create(
          GetExternalSymbolSymbol(MO.getSymbolName()), OutContext));
      break;
    default:
      llvm_unreachable("unexpected MachineOperand kind in Mov asm printer");
    }
    OutMI.addOperand(MCOp);
  }
}

void MovAsmPrinter::emitInstruction(const MachineInstr *MI) {
  MCInst TmpInst;
  lower(MI, TmpInst);
  EmitToStreamer(*OutStreamer, TmpInst);
}

extern "C" void LLVMInitializeMovAsmPrinter() {
  RegisterAsmPrinter<MovAsmPrinter> X(getTheMovTarget());
}
