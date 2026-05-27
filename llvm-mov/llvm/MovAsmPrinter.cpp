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
#include "llvm/BinaryFormat/ELF.h"
#include "llvm/CodeGen/AsmPrinter.h"
#include "llvm/CodeGen/MachineInstr.h"
#include "llvm/CodeGen/MachineOperand.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCInstBuilder.h"
#include "llvm/MC/MCSectionELF.h"
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

  // Stage 7-prep-2a / 7b1: emit byte-table data the MovOnlyLegalize
  // pass indexes. Emitted unconditionally — see the comment in
  // emitAdd8Tables() for the rationale; the bitwise tables follow
  // the same policy in their own sections so --gc-sections can drop
  // them independently when stage 7b1 hasn't produced references.
  void emitEndOfAsmFile(Module & /*M*/) override {
    emitAdd8Tables();
    emitBitwise8Tables();
    emitShift8Tables();
  }

private:
  void lower(const MachineInstr *MI, MCInst &OutMI) const;
  void emitAdd8Tables();
  void emitBitwise8Tables();
  void emitBitwise8Table(StringRef Name, uint8_t (*Op)(uint8_t, uint8_t));
  void emitShift8Tables();
  void emitUnaryByteTable(StringRef Name, uint8_t (*Op)(uint8_t));
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
// them as local symbols — multi-object links don't conflict.
//
// The tables live in their *own* ELF section `.rodata.__mov_add8_tables`,
// not the generic `.rodata`. ld's `--gc-sections` operates per-section,
// so emitting into the shared `.rodata` would keep the tables alive
// whenever any other constant in the TU is live (string literals, FP
// constants, jump tables, etc.). A dedicated section is independently
// GC-eligible, so until MovOnlyLegalize starts producing references at
// stage 7a1, every link drops the 256 KiB at no asm-side cost. Both
// tables share one section because stage 7a1 always references them
// together — splitting them gains nothing.
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

  MCSection *TableSec = OutContext.getELFSection(
      ".rodata.__mov_add8_tables", ELF::SHT_PROGBITS, ELF::SHF_ALLOC);
  OutStreamer->switchSection(TableSec);

  const auto emitTable = [&](StringRef Name, ArrayRef<uint8_t> Data) {
    MCSymbol *Sym = OutContext.getOrCreateSymbol(Name);
    OutStreamer->emitLabel(Sym);
    OutStreamer->emitBytes(StringRef(
        reinterpret_cast<const char *>(Data.data()), Data.size()));
  };
  emitTable("__mov_add8_sum_table", Sum);
  emitTable("__mov_add8_carry_table", Carry);
}

// Stage 7b1 — bitwise byte tables: __mov_and8_table, __mov_or8_table,
// __mov_xor8_table. Each is 256x256 = 64 KiB indexed by (a*256 + b).
// No carry-out, so each op needs only a single table (vs ADD's pair).
//
// Each table lives in its own ELF section `.rodata.__mov_<op>8_table`,
// not the shared .rodata. Bitwise ops are referenced independently —
// a TU might exercise XOR without AND, so per-table sections let
// `ld --gc-sections` drop the unused ones. (ADD's two tables share
// one section because the legalize pass always references them as a
// pair, so there is no GC win from splitting.)
void MovAsmPrinter::emitBitwise8Table(StringRef Name,
                                      uint8_t (*Op)(uint8_t, uint8_t)) {
  static constexpr unsigned kSize = 256u * 256u;
  SmallVector<uint8_t, kSize> Data;
  Data.reserve(kSize);
  for (unsigned a = 0; a < 256; ++a) {
    for (unsigned b = 0; b < 256; ++b) {
      Data.push_back(Op(static_cast<uint8_t>(a), static_cast<uint8_t>(b)));
    }
  }

  std::string SecName = (".rodata." + Name).str();
  MCSection *Sec = OutContext.getELFSection(SecName, ELF::SHT_PROGBITS,
                                            ELF::SHF_ALLOC);
  OutStreamer->switchSection(Sec);

  MCSymbol *Sym = OutContext.getOrCreateSymbol(Name);
  OutStreamer->emitLabel(Sym);
  OutStreamer->emitBytes(StringRef(
      reinterpret_cast<const char *>(Data.data()), Data.size()));
}

void MovAsmPrinter::emitBitwise8Tables() {
  emitBitwise8Table(
      "__mov_and8_table",
      [](uint8_t a, uint8_t b) -> uint8_t { return a & b; });
  emitBitwise8Table(
      "__mov_or8_table",
      [](uint8_t a, uint8_t b) -> uint8_t { return a | b; });
  emitBitwise8Table(
      "__mov_xor8_table",
      [](uint8_t a, uint8_t b) -> uint8_t { return a ^ b; });
}

// Stage 7b2 — unary byte tables for shift legalization.
//
//   __mov_shl_byte_k[a] = (a << k) & 0xFF     (k = 1..7)
//   __mov_shr_byte_k[a] = a >> k              (k = 1..7, unsigned)
//   __mov_sar_sign_byte[a] = (a >> 7) ? 0xFF : 0x00
//
// SAR doesn't need its own shifted-byte tables: it's "SHR with the
// out-of-range high-side source byte replaced by the sign byte"
// (computed once per legalize site from orig[3] via __mov_sar_sign_byte).
//
// Total 15 tables × 256 bytes = 3840 bytes of additional rodata. Each
// lives in its own `.rodata.<sym>` section so `ld --gc-sections` can
// drop the ones whose corresponding shift amount isn't used.
void MovAsmPrinter::emitUnaryByteTable(StringRef Name,
                                       uint8_t (*Op)(uint8_t)) {
  static constexpr unsigned kSize = 256u;
  SmallVector<uint8_t, kSize> Data;
  Data.reserve(kSize);
  for (unsigned a = 0; a < 256; ++a) {
    Data.push_back(Op(static_cast<uint8_t>(a)));
  }

  std::string SecName = (".rodata." + Name).str();
  MCSection *Sec = OutContext.getELFSection(SecName, ELF::SHT_PROGBITS,
                                            ELF::SHF_ALLOC);
  OutStreamer->switchSection(Sec);

  MCSymbol *Sym = OutContext.getOrCreateSymbol(Name);
  OutStreamer->emitLabel(Sym);
  OutStreamer->emitBytes(StringRef(
      reinterpret_cast<const char *>(Data.data()), Data.size()));
}

void MovAsmPrinter::emitShift8Tables() {
  emitUnaryByteTable(
      "__mov_shl_byte_1",
      [](uint8_t a) -> uint8_t { return static_cast<uint8_t>(a << 1); });
  emitUnaryByteTable(
      "__mov_shl_byte_2",
      [](uint8_t a) -> uint8_t { return static_cast<uint8_t>(a << 2); });
  emitUnaryByteTable(
      "__mov_shl_byte_3",
      [](uint8_t a) -> uint8_t { return static_cast<uint8_t>(a << 3); });
  emitUnaryByteTable(
      "__mov_shl_byte_4",
      [](uint8_t a) -> uint8_t { return static_cast<uint8_t>(a << 4); });
  emitUnaryByteTable(
      "__mov_shl_byte_5",
      [](uint8_t a) -> uint8_t { return static_cast<uint8_t>(a << 5); });
  emitUnaryByteTable(
      "__mov_shl_byte_6",
      [](uint8_t a) -> uint8_t { return static_cast<uint8_t>(a << 6); });
  emitUnaryByteTable(
      "__mov_shl_byte_7",
      [](uint8_t a) -> uint8_t { return static_cast<uint8_t>(a << 7); });

  emitUnaryByteTable(
      "__mov_shr_byte_1", [](uint8_t a) -> uint8_t { return a >> 1; });
  emitUnaryByteTable(
      "__mov_shr_byte_2", [](uint8_t a) -> uint8_t { return a >> 2; });
  emitUnaryByteTable(
      "__mov_shr_byte_3", [](uint8_t a) -> uint8_t { return a >> 3; });
  emitUnaryByteTable(
      "__mov_shr_byte_4", [](uint8_t a) -> uint8_t { return a >> 4; });
  emitUnaryByteTable(
      "__mov_shr_byte_5", [](uint8_t a) -> uint8_t { return a >> 5; });
  emitUnaryByteTable(
      "__mov_shr_byte_6", [](uint8_t a) -> uint8_t { return a >> 6; });
  emitUnaryByteTable(
      "__mov_shr_byte_7", [](uint8_t a) -> uint8_t { return a >> 7; });

  emitUnaryByteTable(
      "__mov_sar_sign_byte",
      [](uint8_t a) -> uint8_t {
        return (a & 0x80) ? static_cast<uint8_t>(0xFFu) : static_cast<uint8_t>(0);
      });

  // Stage 7b3 — `__mov_select_mask_table[a] = a ? 0xFF : 0x00`. Used
  // by the variable-shift (rCL) legalize to turn the per-bit
  // `amount & (1 << k)` flag into a full-byte mask suitable for an
  // AND/OR-based 32-bit conditional select.
  emitUnaryByteTable(
      "__mov_select_mask_table",
      [](uint8_t a) -> uint8_t {
        return a ? static_cast<uint8_t>(0xFFu) : static_cast<uint8_t>(0);
      });
}

extern "C" void LLVMInitializeMovAsmPrinter() {
  RegisterAsmPrinter<MovAsmPrinter> X(getTheMovTarget());
}
