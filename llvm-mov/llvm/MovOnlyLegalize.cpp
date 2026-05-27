//===-- MovOnlyLegalize.cpp -------------------------------------*- C++ -*-===//
//
// MovOnlyLegalize — a MachineFunctionPass that rewrites every non-`mov`
// instruction the backend emitted at stages 0–6 into mov-only sequences.
// This is the whole project's namesake.
//
// At this point (stage 7a0) the pass is **structural only**. It registers
// itself with the codegen pipeline (after RegAlloc/PEI/BranchFolder,
// before AsmPrinter) and walks every MachineInstr, but it never rewrites
// anything yet. The point of the empty pass is to lock down the wiring —
// pass position, MIR-shape invariants, command-line gate — before the
// (much harder) per-opcode legalization starts landing.
//
// Stage breakdown for what's coming, per codex's stage-7 design pass:
//   7a0  this commit — pass skeleton + addPreEmitPass wiring + docs
//   7a1  ADD32rr/ri  — first real legalization, via .rodata byte-add
//                      lookup tables. Each 32-bit add is decomposed into
//                      four 8-bit adds chained by carry; the per-byte
//                      add is a pair of table reads
//                      (__mov_add8_sum_table / __mov_add8_carry_table)
//                      indexed by (cin, a_byte, b_byte). A PoC fixture
//                      verifies one function lowers to mov-only.
//                      Requires the stage 7-prep-2 infrastructure (see
//                      legalizeADD32 below).
//   7b1  AND/OR/XOR  — straightforward extension of the 7a1 framework.
//   7b2  SHL/SHR/SAR — separate because shift carry/bit-extraction is a
//                      different table shape from add.
//   7c   CMP+Jcc+JMP — must be legalised as a unit; the control-flow
//                      substrate changes. Codex flagged segment-register
//                      self-modification (the famous movfuscator trick)
//                      as a *trap* if used here first: ELF section
//                      permissions + W^X + the late-MI CFG world
//                      collide. Initial 7c will use a branchless
//                      dispatcher instead.
//   7d   CALL+RET    — call/ret share the return-address machinery,
//                      so they're done together once 7c's substrate is
//                      in place.
//
// The pass also gates an `objdump`-based check in test/MovOnly/run.sh:
// "the .text section of every fixture must contain only mov-family
// opcodes" (modulo the `int 0x80` we whitelist in `_start.s`). At 7a0
// that gate fails on every fixture (we haven't legalised anything yet)
// — but it's wired up so each successive 7-stage lights up another
// fixture group.
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/MovMCTargetDesc.h"
#include "MovInstrInfo.h"
#include "MovTargetMachine.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstr.h"
#include "llvm/CodeGen/Passes.h"
#include "llvm/InitializePasses.h"
#include "llvm/Pass.h"

using namespace llvm;

#define DEBUG_TYPE "mov-only-legalize"

namespace {
class MovOnlyLegalize : public MachineFunctionPass {
public:
  static char ID;
  MovOnlyLegalize() : MachineFunctionPass(ID) {}

  StringRef getPassName() const override {
    return "Mov-Only Legalization (stage 7+)";
  }

  bool runOnMachineFunction(MachineFunction &MF) override {
    bool Changed = false;
    for (MachineBasicBlock &MBB : MF) {
      for (MachineInstr &MI :
           llvm::make_early_inc_range(MBB)) {
        switch (MI.getOpcode()) {
        case Mov::ADD32rr:
        case Mov::ADD32ri:
          Changed |= legalizeADD32(MI);
          break;
        // The remaining opcodes (SUB/AND/OR/XOR rr+ri, SHL/SHR/SAR
        // ri/rCL, CMP+Jcc family, CALL32d + CALLSEQ, RET) light up
        // in stages 7b → 7d. Each will have its own legalizeXxx
        // helper here.
        default:
          break;
        }
      }
    }
    return Changed;
  }

private:
  // Stage-7a1 placeholder — see the file-level comment for the design.
  //
  // The full implementation needs the following infrastructure we
  // haven't built yet (call this list "stage 7-prep-2"):
  //
  //   1. `.rodata` table emission: a 256x256 byte-add table indexed by
  //      (a, b, carry-in) returning (sum, carry-out). Either emitted
  //      as a `Module`-level GlobalVariable via a separate ModulePass,
  //      or as raw `.byte` directives in MovAsmPrinter::emitEndOfAsmFile.
  //
  //   2. SIB-style `[base + index]` addressing for MOV8rm. Our current
  //      MovMemOperand is `(base_reg, disp_imm)` only; to use a byte
  //      held in CL/AL/etc. as a table index we need the index-register
  //      form. This is a new Operand kind in MovInstrInfo.td and a
  //      new path in SelectAddr.
  //
  //   3. Per-function scratch slots for spilling parent regs (EAX/etc.)
  //      around byte-reg usage. MovOnlyLegalize must allocate these
  //      via MFI.CreateStackObject, since RA has already finished.
  //
  // Until those are in place, this returns false so the pass stays a
  // no-op for ADD32 — gated by the test/MovOnly/ harness which has no
  // ADD-focused fixtures yet. Returning false here keeps the existing
  // 39 execution tests + Rust example green; the mov-only gate stays
  // empty.
  bool legalizeADD32(MachineInstr & /*MI*/) const {
    // TODO(stage 7a1, post 7-prep-2): byte-split + carry-chain table
    // lookups. See file-level comment.
    return false;
  }
};
} // namespace

char MovOnlyLegalize::ID = 0;

FunctionPass *llvm::createMovOnlyLegalizePass() {
  return new MovOnlyLegalize();
}
