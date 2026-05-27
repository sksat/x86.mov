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
#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/CodeGen/AsmPrinter.h"
#include "llvm/CodeGen/MachineInstr.h"
#include "llvm/CodeGen/MachineOperand.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCInstBuilder.h"
#include "llvm/MC/MCObjectFileInfo.h"
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

  // Stage 7-prep-2a: emit byte-add lookup tables that the MovOnlyLegalize
  // pass will index from stage 7a1 onward. Emitted unconditionally — see
  // the comment in emitAdd8Tables() for the rationale.
  void emitEndOfAsmFile(Module & /*M*/) override { emitAdd8Tables(); }

private:
  void lower(const MachineInstr *MI, MCInst &OutMI) const;
  void emitAdd8Tables();
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
    case MachineOperand::MO_GlobalAddress: {
      // Stage 5a doesn't emit any calls yet, but adding the case now
      // keeps lower() honest for stage 6: `call <global>` is the next
      // thing that lands here. Fold MO.getOffset() into the MCExpr so
      // `@g + C` shapes (e.g. constant GEPs into a global) reference
      // the right byte — codex's stage-5a review flagged that dropping
      // the offset would silently misaddress.
      const MCExpr *Expr = MCSymbolRefExpr::create(
          getSymbol(MO.getGlobal()), OutContext);
      if (int64_t Off = MO.getOffset()) {
        Expr = MCBinaryExpr::createAdd(
            Expr, MCConstantExpr::create(Off, OutContext), OutContext);
      }
      MCOp = MCOperand::createExpr(Expr);
      break;
    }
    case MachineOperand::MO_ExternalSymbol: {
      const MCExpr *Expr = MCSymbolRefExpr::create(
          GetExternalSymbolSymbol(MO.getSymbolName()), OutContext);
      if (int64_t Off = MO.getOffset()) {
        Expr = MCBinaryExpr::createAdd(
            Expr, MCConstantExpr::create(Off, OutContext), OutContext);
      }
      MCOp = MCOperand::createExpr(Expr);
      break;
    }
    case MachineOperand::MO_RegisterMask:
      // Call regmask: not part of the printed asm, but the MachineOperand
      // exists so RA / liveness know which registers the call clobbers.
      // Skip silently — the asm just prints `call <callee>`.
      continue;
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

// Stage 7-prep-2a:
//   __mov_add8_sum_table[cin][a][b]   = (cin + a + b) & 0xFF
//   __mov_add8_carry_table[cin][a][b] = (cin + a + b) >> 8   (∈ {0,1})
//
// Each table is 2 * 256 * 256 = 131072 bytes, laid out in
// (cin, a, b)-major order so a byte add at carry-chain step `i` reads
//     sum_byte_i   = __mov_add8_sum_table  [cin*65536 + a_i*256 + b_i]
//     carry_out_i  = __mov_add8_carry_table[cin*65536 + a_i*256 + b_i]
//
// The MovOnlyLegalize pass at stage 7a1 will lower ADD32rr/ri to four
// such per-byte lookups chained by carry. This printer-side hook owns
// the data emission so MovOnlyLegalize can stay focused on MI rewriting
// and never touch Module-level IR (no ModulePass / no GlobalVariable).
//
// Emission policy: unconditional, once per translation unit, after all
// functions. The symbols are not declared `.globl`, so each .o keeps
// them as local symbols — multi-object links don't conflict, and
// `ld --gc-sections` is free to drop them when MovOnlyLegalize hasn't
// produced any references. PoC overhead is ~256 KiB / object; for the
// current 39 execution fixtures this is academic.
void MovAsmPrinter::emitAdd8Tables() {
  static constexpr unsigned kSize = 2u * 256u * 256u;
  SmallVector<uint8_t, kSize> Sum;
  SmallVector<uint8_t, kSize> Carry;
  Sum.reserve(kSize);
  Carry.reserve(kSize);
  for (unsigned cin = 0; cin < 2; ++cin) {
    for (unsigned a = 0; a < 256; ++a) {
      for (unsigned b = 0; b < 256; ++b) {
        const unsigned s = a + b + cin;
        Sum.push_back(static_cast<uint8_t>(s & 0xFF));
        Carry.push_back(static_cast<uint8_t>(s >> 8));
      }
    }
  }

  MCSection *RoSec = OutContext.getObjectFileInfo()->getReadOnlySection();
  OutStreamer->switchSection(RoSec);

  const auto emitTable = [&](StringRef Name, ArrayRef<uint8_t> Data) {
    MCSymbol *Sym = OutContext.getOrCreateSymbol(Name);
    OutStreamer->emitLabel(Sym);
    OutStreamer->emitBytes(StringRef(
        reinterpret_cast<const char *>(Data.data()), Data.size()));
  };
  emitTable("__mov_add8_sum_table", Sum);
  emitTable("__mov_add8_carry_table", Carry);
}

extern "C" void LLVMInitializeMovAsmPrinter() {
  RegisterAsmPrinter<MovAsmPrinter> X(getTheMovTarget());
}
