//===-- MovMCTargetDesc.cpp -----------------------------------------------===//
//
// Glue between the TableGen-generated MC descriptors and the LLVM MC layer.
// Each `createXxx` is what RegisterMCXxx asks for at the entry point below.
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/MovMCTargetDesc.h"
#include "MCTargetDesc/MovInstPrinter.h"
#include "MCTargetDesc/MovMCAsmInfo.h"
#include "TargetInfo/MovTargetInfo.h"
#include "llvm/MC/MCInstrInfo.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/TargetParser/Triple.h"

using namespace llvm;

#define GET_INSTRINFO_MC_DESC
#define ENABLE_INSTR_PREDICATE_VERIFIER
#include "MovGenInstrInfo.inc"

#define GET_REGINFO_MC_DESC
#include "MovGenRegisterInfo.inc"

#define GET_SUBTARGETINFO_MC_DESC
#include "MovGenSubtargetInfo.inc"

static MCInstrInfo *createMovMCInstrInfo() {
  auto *X = new MCInstrInfo();
  InitMovMCInstrInfo(X);
  return X;
}

static MCRegisterInfo *createMovMCRegisterInfo(const Triple & /*TT*/) {
  auto *X = new MCRegisterInfo();
  // The RA register (the one that holds the return address) is conceptually
  // ESP+0 in cdecl, but we don't expose a separate slot yet — set to 0.
  InitMovMCRegisterInfo(X, /*RA=*/0);
  return X;
}

static MCSubtargetInfo *
createMovMCSubtargetInfo(const Triple &TT, StringRef CPU, StringRef FS) {
  return createMovMCSubtargetInfoImpl(TT, CPU, /*TuneCPU=*/CPU, FS);
}

static MCInstPrinter *createMovMCInstPrinter(const Triple & /*TT*/,
                                             unsigned SyntaxVariant,
                                             const MCAsmInfo &MAI,
                                             const MCInstrInfo &MII,
                                             const MCRegisterInfo &MRI) {
  if (SyntaxVariant == 0)
    return new MovInstPrinter(MAI, MII, MRI);
  return nullptr;
}

extern "C" void LLVMInitializeMovTargetMC() {
  Target &T = getTheMovTarget();

  RegisterMCAsmInfo<MovMCAsmInfo>      X(T);
  TargetRegistry::RegisterMCInstrInfo  (T, createMovMCInstrInfo);
  TargetRegistry::RegisterMCRegInfo    (T, createMovMCRegisterInfo);
  TargetRegistry::RegisterMCSubtargetInfo(T, createMovMCSubtargetInfo);
  TargetRegistry::RegisterMCInstPrinter(T, createMovMCInstPrinter);
}
