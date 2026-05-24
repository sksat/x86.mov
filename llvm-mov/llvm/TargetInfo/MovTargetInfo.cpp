//===-- MovTargetInfo.cpp -------------------------------------------------===//
//
// Registers the singleton `Mov` Target with the LLVM TargetRegistry under the
// triple architecture name `mov`. Everything else (MC layer, codegen, asm
// printer) keys off this Target&.
//
//===----------------------------------------------------------------------===//

#include "TargetInfo/MovTargetInfo.h"
#include "llvm/MC/TargetRegistry.h"

using namespace llvm;

Target &llvm::getTheMovTarget() {
  static Target TheMovTarget;
  return TheMovTarget;
}

extern "C" void LLVMInitializeMovTargetInfo() {
  RegisterTarget<Triple::UnknownArch, /*HasJIT=*/false> X(
      getTheMovTarget(), "mov", "Mov (mov-only x86-32 backend)", "Mov");
}
