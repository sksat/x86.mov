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
#include "llvm/ADT/StringSwitch.h"
#include "llvm/IR/Module.h"
#include "llvm/MC/MCSectionELF.h"
#include "llvm/MC/MCStreamer.h"
#include "llvm/MC/MCSymbol.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

// Defined below, next to the alias machinery that is its main consumer.
static bool isGasIntelReservedWord(StringRef Name);

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
  //
  // While we have the Module, note whether anything in it is named after
  // a GAS Intel-syntax reserved word — see emitGlobalVariable below for
  // what that costs us.
  void emitStartOfAsmFile(Module &M) override {
    OutStreamer->emitRawText(StringRef(".intel_syntax noprefix"));
    for (const GlobalValue &GV : M.global_values()) {
      if (isGasIntelReservedWord(GV.getName())) {
        HasGasKeywordSymbol = true;
        break;
      }
    }
  }

  // Data initialisers that reference a reserved-word symbol are the other
  // half of the problem `aliasIfGasKeyword` solves for instruction
  // operands — and the nastier half, because they fail *quietly*:
  //
  //     @p = global ptr @offset      ->      p: .long offset
  //
  // assembles with only `Warning: zero assumed for missing expression`
  // and stores 0. `as` exits 0, so nothing downstream notices that the
  // pointer is null.
  //
  // The alias trick doesn't reach here: the base AsmPrinter emits
  // initialisers itself, without going through our lower(). Rather than
  // duplicate constant emission, emit global variables in AT&T syntax —
  // where these words are not reserved — and switch back afterwards. The
  // directives themselves (`.long`, `.globl`, `.p2align`, `.size`) are
  // syntax-neutral, so nothing else changes.
  //
  // Only done when the module actually contains such a symbol, so the
  // usual output is untouched.
  void emitGlobalVariable(const GlobalVariable *GV) override {
    if (!HasGasKeywordSymbol) {
      AsmPrinter::emitGlobalVariable(GV);
      return;
    }
    OutStreamer->emitRawText(StringRef(".att_syntax"));
    AsmPrinter::emitGlobalVariable(GV);
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
    emitSub8Tables();
    emitPopcount8Table();
    emitBitscan8Tables();
    emitMul8Tables();
    emitReturnAddrSlot();
    emitEspDecScratch();
    emitIndirectCalleeSlot();
    emitGasKeywordAliases();
  }

private:
  void lower(const MachineInstr *MI, MCInst &OutMI) const;

  // GAS's Intel-syntax parser reserves a handful of words, and several of
  // them are perfectly ordinary C identifiers — lcc has a global called
  // `offset`. A symbol so named cannot be referenced in Intel syntax at
  // all: `mov esi, offset offset` is "invalid expression", `mov eax,
  // offset and` is "invalid use of operator", and every parenthesised /
  // `flat:` / `@GOTOFF` / `+0` variant was measured to fail too (binutils
  // 2.47).
  //
  // The one spelling that works is to reference an alias and define that
  // alias in a short `.att_syntax` window, where the words are not
  // reserved:
  //
  //     .att_syntax
  //     .set .Lmov_kw_offset, offset
  //     .intel_syntax noprefix
  //
  // `aliasIfGasKeyword` swaps the symbol for its alias at operand-lowering
  // time and records it; `emitGasKeywordAliases` emits the definitions at
  // the end of the file. Symbols with ordinary names are returned
  // unchanged, so nothing else in the output moves.
  MCSymbol *aliasIfGasKeyword(MCSymbol *Sym) const;
  void emitGasKeywordAliases();

  // Original-name → alias, in insertion order so the emitted asm is
  // deterministic. Mutable because lower() is const.
  mutable SmallVector<std::pair<std::string, MCSymbol *>, 4> GasKeywordAliases;

  // Set in emitStartOfAsmFile when the module names anything after a GAS
  // Intel-syntax reserved word. Gates the data-emission workaround above.
  bool HasGasKeywordSymbol = false;
  void emitAdd8Tables();
  void emitBitwise8Tables();
  void emitBitwise8Table(StringRef Name, uint8_t (*Op)(uint8_t, uint8_t));
  void emitShift8Tables();
  void emitUnaryByteTable(StringRef Name, uint8_t (*Op)(uint8_t));
  void emitSub8Tables();
  void emitPopcount8Table();
  void emitBitscan8Tables();
  void emitMul8Tables();
  void emitReturnAddrSlot();
  void emitEspDecScratch();
  void emitIndirectCalleeSlot();
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
          aliasIfGasKeyword(getSymbol(MO.getGlobal())), OutContext);
      if (int64_t Off = MO.getOffset()) {
        Expr = MCBinaryExpr::createAdd(
            Expr, MCConstantExpr::create(Off, OutContext), OutContext);
      }
      MCOp = MCOperand::createExpr(Expr);
      break;
    }
    case MachineOperand::MO_ExternalSymbol: {
      const MCExpr *Expr = MCSymbolRefExpr::create(
          aliasIfGasKeyword(GetExternalSymbolSymbol(MO.getSymbolName())),
          OutContext);
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
// GC-eligible. Both tables share one section because stage 7a1 always
// references them together — splitting them gains nothing.
//
// Note: at stage 7d the byte-add chain ends up referenced by every
// non-trivial program (stage 7d1's `add esp, 8` for ret + post-call
// add esp), so `--gc-sections` keeps the 256 KiB live in most linked
// ELFs. Trivial fixtures with no ret/post-call ADD (rare) still drop
// it. `bench/results.md`'s `.rodata` column shows which fixtures
// retain how much of the table set.
// The set was measured against binutils 2.47 by assembling `mov esi,
// offset NAME` for each candidate; exactly these failed. They split into
// two flavours — plain reserved words (`offset`, `short`, `flat`, `st`)
// and words that are also binary operators (`and`, `or`, `not`, `xor`,
// `shl`, `shr`, `mod`) — but the alias treatment covers both, so the
// printer does not need to tell them apart.
//
// The match is case-insensitive because GAS's Intel-syntax keywords are:
// `OFFSET`, `Offset` and `oFFsEt` all collide just as `offset` does
// (measured the same way). Only the *lookup* is folded — the alias is
// still defined against the symbol's original spelling, which is what
// the linker sees.
static bool isGasIntelReservedWord(StringRef Name) {
  return llvm::StringSwitch<bool>(Name.lower())
      .Cases({"offset", "mod", "short", "flat", "st"}, true)
      .Cases({"and", "or", "not", "xor", "shl", "shr"}, true)
      .Default(false);
}

MCSymbol *MovAsmPrinter::aliasIfGasKeyword(MCSymbol *Sym) const {
  const StringRef Name = Sym->getName();
  if (!isGasIntelReservedWord(Name))
    return Sym;

  for (const auto &[Orig, Alias] : GasKeywordAliases)
    if (Orig == Name)
      return Alias;

  // createTempSymbol, not getOrCreateSymbol: a fixed name like
  // `.Lmov_kw_offset` could collide with a symbol that actually exists in
  // the input, in which case references would silently be redirected to
  // it and the `.set` below would redefine it. The temp-symbol counter
  // guarantees a fresh name.
  MCSymbol *Alias = OutContext.createTempSymbol(Twine("mov_kw_") + Name);
  GasKeywordAliases.emplace_back(Name.str(), Alias);
  return Alias;
}

void MovAsmPrinter::emitGasKeywordAliases() {
  if (GasKeywordAliases.empty())
    return;
  OutStreamer->emitRawText(StringRef(".att_syntax"));
  for (const auto &[Orig, Alias] : GasKeywordAliases)
    OutStreamer->emitRawText(Twine(".set ") + Alias->getName() + ", " + Orig);
  OutStreamer->emitRawText(StringRef(".intel_syntax noprefix"));
}

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

// Stage 7c3 — byte-subtract lookup tables used by the CMP+Jcc rewrite
// when the predicate is an unsigned comparison (B/AE/BE/A) and, from
// stage 7c4, signed comparisons (L/GE/LE/G). The pair is shaped like
// the add8 tables but encodes `(a - b - cin)` instead of `(a + b + cin)`:
//
//   __mov_sub8_diff_table  [cin][a][b] = (a - b - cin) & 0xFF
//   __mov_sub8_borrow_table[cin][a][b] = ((a - b - cin) >> 31) & 1
//                                        — 1 iff the subtract underflowed
//
// Layout matches the add8 pair (cin-major, then a, then b) so the same
// idx-pack mechanism works for both. Both tables share a single
// `.rodata.__mov_sub8_tables` section — they're always referenced as a
// pair by the legalize pass, so independent GC buys nothing. Total
// 256 KiB; linked only when a function references the symbols
// (i.e. when stage 7c3+ has rewritten a CMP+Jcc on an unsigned/signed
// predicate).
void MovAsmPrinter::emitSub8Tables() {
  static constexpr unsigned kSize = 2u * 256u * 256u;
  SmallVector<uint8_t, kSize> Diff;
  SmallVector<uint8_t, kSize> Borrow;
  Diff.reserve(kSize);
  Borrow.reserve(kSize);
  for (unsigned cin = 0; cin < 2; ++cin) {
    for (unsigned a = 0; a < 256; ++a) {
      for (unsigned b = 0; b < 256; ++b) {
        const int d = static_cast<int>(a) - static_cast<int>(b) -
                      static_cast<int>(cin);
        Diff.push_back(static_cast<uint8_t>(d & 0xFF));
        Borrow.push_back(static_cast<uint8_t>(d < 0 ? 1 : 0));
      }
    }
  }

  MCSection *TableSec = OutContext.getELFSection(
      ".rodata.__mov_sub8_tables", ELF::SHT_PROGBITS, ELF::SHF_ALLOC);
  OutStreamer->switchSection(TableSec);

  const auto emitTable = [&](StringRef Name, ArrayRef<uint8_t> Data) {
    MCSymbol *Sym = OutContext.getOrCreateSymbol(Name);
    OutStreamer->emitLabel(Sym);
    OutStreamer->emitBytes(StringRef(
        reinterpret_cast<const char *>(Data.data()), Data.size()));
  };
  emitTable("__mov_sub8_diff_table", Diff);
  emitTable("__mov_sub8_borrow_table", Borrow);
}

// Stage 7e — `__mov_popcount8_table[a] = popcount(a)` for a ∈ 0..255.
// Each entry fits in 4 bits (max value 8), so 1 byte / entry is plenty.
// Indexed by `mov dl, byte ptr [__mov_popcount8_table + ecx]` after the
// caller has packed the source byte into ECX via the standard idx-slot
// dance (idx[0] = src_byte, idx[1..3] = 0 → ecx = src_byte). Lives in
// its own ELF section so `ld --gc-sections` drops the 256 bytes from
// TUs that contain no `llvm.ctpop.i32`.
void MovAsmPrinter::emitPopcount8Table() {
  SmallVector<uint8_t, 256> Data;
  Data.reserve(256);
  for (unsigned a = 0; a < 256; ++a) {
    uint8_t pc = 0;
    for (unsigned b = a; b; b &= b - 1)
      ++pc;
    Data.push_back(pc);
  }

  MCSection *Sec = OutContext.getELFSection(
      ".rodata.__mov_popcount8_table", ELF::SHT_PROGBITS, ELF::SHF_ALLOC);
  OutStreamer->switchSection(Sec);
  MCSymbol *Sym = OutContext.getOrCreateSymbol("__mov_popcount8_table");
  OutStreamer->emitLabel(Sym);
  OutStreamer->emitBytes(StringRef(
      reinterpret_cast<const char *>(Data.data()), Data.size()));
}

// Stage 7e — byte tables consumed by the CTLZ32r / CTTZ32r legalize.
//
//   __mov_zero_mask_table[a]  = (a == 0) ? 0xFF : 0x00
//     Used to update the per-iteration `alive` mask: alive_next =
//     alive AND zero_mask[b]. So once a non-zero byte is crossed,
//     alive flips to 0x00 and stays there for the rest of the scan.
//
//   __mov_clz_or_8_table[a]   = (a == 0) ? 8 : (count of leading
//                                                zeros in `a` as
//                                                an 8-bit value)
//   __mov_ctz_or_8_table[a]   = (a == 0) ? 8 : (count of trailing
//                                                zeros in `a` as
//                                                an 8-bit value)
//     Each per-byte iteration looks one of these up to get the
//     "contribution if this is the first non-zero byte (CLZ/CTZ of
//     this byte) or otherwise add 8 to advance past a zero byte"
//     choice. The choice is then AND-masked by `alive` and added
//     into the running total via `__mov_add8_sum_table`.
//
// Each table is 256 bytes and lives in its own `.rodata.<sym>`
// section so `ld --gc-sections` drops the unreferenced ones per-TU.
void MovAsmPrinter::emitBitscan8Tables() {
  emitUnaryByteTable(
      "__mov_zero_mask_table",
      [](uint8_t a) -> uint8_t {
        return a == 0 ? static_cast<uint8_t>(0xFFu) : static_cast<uint8_t>(0);
      });
  emitUnaryByteTable(
      "__mov_clz_or_8_table",
      [](uint8_t a) -> uint8_t {
        if (a == 0)
          return 8;
        uint8_t c = 0;
        while ((a & 0x80u) == 0) {
          ++c;
          a = static_cast<uint8_t>(a << 1);
        }
        return c;
      });
  emitUnaryByteTable(
      "__mov_ctz_or_8_table",
      [](uint8_t a) -> uint8_t {
        if (a == 0)
          return 8;
        uint8_t c = 0;
        while ((a & 0x01u) == 0) {
          ++c;
          a = static_cast<uint8_t>(a >> 1);
        }
        return c;
      });
}

// Stage 7f — `__mov_mul8_lo_table` and `__mov_mul8_hi_table`, each
// 256 × 256 = 64 KiB:
//
//   __mov_mul8_lo_table[a*256 + b] = (a * b) & 0xFF        (low byte)
//   __mov_mul8_hi_table[a*256 + b] = (a * b) >> 8          (high byte)
//
// Indexed by `mov dl, byte ptr [__mov_mul8_*_table + ecx]` after the
// caller has packed (a_byte << 8) | b_byte into ECX via the standard
// idx-slot dance (idx[0] = b, idx[1] = a, idx[2..3] = 0 → ecx =
// a*256+b). The two tables live in a shared `.rodata.__mov_mul8_tables`
// section because every MUL site looks up both; per-table sections
// would waste a section header for no GC win.
//
// Total 128 KiB rodata, only paid by TUs that contain at least one
// MUL32{rr,ri}; bench-check confirms TUs without MUL stay byte-
// identical via `ld --gc-sections`.
void MovAsmPrinter::emitMul8Tables() {
  static constexpr unsigned kSize = 256u * 256u;
  SmallVector<uint8_t, kSize> Lo;
  SmallVector<uint8_t, kSize> Hi;
  Lo.reserve(kSize);
  Hi.reserve(kSize);
  for (unsigned a = 0; a < 256; ++a) {
    for (unsigned b = 0; b < 256; ++b) {
      const unsigned p = a * b;
      Lo.push_back(static_cast<uint8_t>(p & 0xFFu));
      Hi.push_back(static_cast<uint8_t>(p >> 8));
    }
  }

  MCSection *TableSec = OutContext.getELFSection(
      ".rodata.__mov_mul8_tables", ELF::SHT_PROGBITS, ELF::SHF_ALLOC);
  OutStreamer->switchSection(TableSec);

  const auto emitTable = [&](StringRef Name, ArrayRef<uint8_t> Data) {
    MCSymbol *Sym = OutContext.getOrCreateSymbol(Name);
    OutStreamer->emitLabel(Sym);
    OutStreamer->emitBytes(StringRef(
        reinterpret_cast<const char *>(Data.data()), Data.size()));
  };
  emitTable("__mov_mul8_lo_table", Lo);
  emitTable("__mov_mul8_hi_table", Hi);
}

// Stage 7d2 — `__mov_esp_dec_scratch`: a 16-byte cell in .bss used
// by the prologue-head rewrite (PUSH32r EBP → mov-only sequence).
// At the entry MI EBP still holds the caller's value, so the usual
// [ebp + scratch_disp] addressing isn't available. The earlier draft
// used [esp - 12]..[esp - 16] as scratch, but writes below ESP can
// fault on a guard page (codex P1 review on 7d2). A .bss slot is
// always mapped, so the rewrite stays correctness-safe across any
// caller stack shape.
//
// Layout:
//   [0..3]   srcdst — current ESP value, decremented in place
//   [4..7]   idx    — (K, a_byte, borrow_in, 0) pack for sub8 lookup
//   [8..15]  unused (reserved for future expansion)
//
// Lives in its own section so --gc-sections drops it from TUs that
// don't reference the symbol.
void MovAsmPrinter::emitEspDecScratch() {
  MCSection *Sec = OutContext.getELFSection(
      ".bss.__mov_esp_dec_scratch",
      ELF::SHT_NOBITS, ELF::SHF_ALLOC | ELF::SHF_WRITE);
  OutStreamer->switchSection(Sec);
  MCSymbol *Sym = OutContext.getOrCreateSymbol("__mov_esp_dec_scratch");
  OutStreamer->emitLabel(Sym);
  OutStreamer->emitZeros(/*NumBytes=*/16);
}

// Stage 7d1 — `__mov_return_addr_slot`: a 4-byte cell in .bss that the
// epilogue-tail rewrite (POP32r EBP + RET → mov-only sequence) uses to
// stash the function's return address before tearing down EBP. The slot
// is read once at the very end of the rewrite (`jmp dword ptr
// [__mov_return_addr_slot]`) and then becomes free again — single-
// threaded, signal-handler-free assumption holds for the bootstrap
// runtime.
//
// One global slot is sufficient: recursion is safe because each function
// runs the stash-then-jump pair atomically before any nested call's
// return can reach this point. (Concurrent rets from a signal handler
// would clobber the slot, but the bootstrap pipeline installs none.)
//
// Lives in `.bss.__mov_return_addr_slot` so --gc-sections can drop it
// when no function references it (stage 7d1 fixtures bring the
// reference in via legalizeRetEpilogueTail's BuildMI).
void MovAsmPrinter::emitReturnAddrSlot() {
  MCSection *Sec = OutContext.getELFSection(
      ".bss.__mov_return_addr_slot",
      ELF::SHT_NOBITS, ELF::SHF_ALLOC | ELF::SHF_WRITE);
  OutStreamer->switchSection(Sec);
  MCSymbol *Sym = OutContext.getOrCreateSymbol("__mov_return_addr_slot");
  OutStreamer->emitLabel(Sym);
  OutStreamer->emitZeros(/*NumBytes=*/4);
}

// CALL32r legalize — `__mov_indirect_callee_slot`: a 4-byte cell in
// .bss used to stash the function-pointer value across the 7d3
// byte-chain (which clobbers EAX/ECX/EDX). The save happens just
// before the chain; the reload happens immediately before the
// trailing JMP32r_CALL terminator. Single-shot per call site, so
// one global slot is sufficient — recursion is safe because the
// save→jmp sequence runs atomically before any nested call's
// return reaches this point (same reasoning as
// __mov_return_addr_slot).
//
// Lives in its own section so --gc-sections drops it from TUs that
// don't reference the symbol (i.e. modules with no indirect calls).
void MovAsmPrinter::emitIndirectCalleeSlot() {
  MCSection *Sec = OutContext.getELFSection(
      ".bss.__mov_indirect_callee_slot",
      ELF::SHT_NOBITS, ELF::SHF_ALLOC | ELF::SHF_WRITE);
  OutStreamer->switchSection(Sec);
  MCSymbol *Sym =
      OutContext.getOrCreateSymbol("__mov_indirect_callee_slot");
  OutStreamer->emitLabel(Sym);
  OutStreamer->emitZeros(/*NumBytes=*/4);
}

extern "C" void LLVMInitializeMovAsmPrinter() {
  RegisterAsmPrinter<MovAsmPrinter> X(getTheMovTarget());
}
