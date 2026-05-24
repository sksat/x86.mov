//===-- MovMCAsmInfo.h ------------------------------------------*- C++ -*-===//
#pragma once

#include "llvm/MC/MCAsmInfoELF.h"

namespace llvm {
class MCTargetOptions;
class Triple;

// ELF, Intel-syntax-ish, 32-bit. Lives in the MC layer so InstPrinter +
// AsmStreamer pick it up uniformly.
class MovMCAsmInfo : public MCAsmInfoELF {
public:
  MovMCAsmInfo(const Triple &TT, const MCTargetOptions &Options);
};
} // namespace llvm
