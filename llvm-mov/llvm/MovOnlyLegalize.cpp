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
//   7a1  ADD32rr/ri  — first real legalization, via .rodata lookup
//                      tables widened to i32 cells (so MOV8/16rm isn't
//                      a prerequisite); a PoC fixture verifies one
//                      function lowers to mov-only.
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

#include "MovInstrInfo.h"
#include "MovTargetMachine.h"
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
    // Stage 7a0: structural pass — walks the function but rewrites
    // nothing. Later stages (7a1+) will replace this loop with a real
    // per-opcode dispatch table that emits mov-only sequences.
    bool Changed = false;
    for (const MachineBasicBlock &MBB : MF) {
      for (const MachineInstr &MI : MBB) {
        (void)MI;
        // Per-opcode rewriting lands at stage 7a1 (ADD32) onwards.
      }
    }
    return Changed;
  }
};
} // namespace

char MovOnlyLegalize::ID = 0;

FunctionPass *llvm::createMovOnlyLegalizePass() {
  return new MovOnlyLegalize();
}
