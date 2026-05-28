//===-- MovSubtarget.cpp --------------------------------------------------===//
#include "MovSubtarget.h"
#include "MovTargetMachine.h"

#define GET_SUBTARGETINFO_TARGET_DESC
#define GET_SUBTARGETINFO_CTOR
#include "MovGenSubtargetInfo.inc"

using namespace llvm;

MovSubtarget::MovSubtarget(const Triple &TT, StringRef CPU, StringRef FS,
                           const TargetMachine &TM)
    : MovGenSubtargetInfo(TT, CPU, /*TuneCPU=*/CPU, FS),
      RegInfo(),
      InstrInfo(*this, RegInfo),
      FrameLowering(),
      TLInfo(TM, *this),
      TSInfo() {}
