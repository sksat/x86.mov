//===-- MovMCAsmInfo.cpp --------------------------------------------------===//
#include "MCTargetDesc/MovMCAsmInfo.h"
#include "llvm/TargetParser/Triple.h"

using namespace llvm;

MovMCAsmInfo::MovMCAsmInfo(const Triple & /*TT*/,
                           const MCTargetOptions & /*Options*/) {
  // Pointer/calling-frame are 32-bit even though the host LLVM is built 64-bit.
  CodePointerSize       = 4;
  CalleeSaveStackSlotSize = 4;
  IsLittleEndian        = true;

  // GAS-flavoured Intel syntax (`mov\teax, 0`). The runner injects
  //   .intel_syntax noprefix
  // at the top of our `.s` output so `as` accepts it.
  CommentString         = "#";
  PrivateGlobalPrefix   = ".L";
  AlignmentIsInBytes    = false;
  UsesELFSectionDirectiveForBSS = true;
  SupportsDebugInformation = false;  // stage 0 — no DWARF yet
}
