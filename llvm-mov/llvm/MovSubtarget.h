//===-- MovSubtarget.h ------------------------------------------*- C++ -*-===//
#pragma once

#include "MovFrameLowering.h"
#include "MovISelLowering.h"
#include "MovInstrInfo.h"
#include "MovRegisterInfo.h"
#include "llvm/CodeGen/SelectionDAGTargetInfo.h"

#define GET_SUBTARGETINFO_HEADER
#include "MovGenSubtargetInfo.inc"

namespace llvm {
class StringRef;
class TargetMachine;

class MovSubtarget : public MovGenSubtargetInfo {
public:
  MovSubtarget(const Triple &TT, StringRef CPU, StringRef FS,
               const TargetMachine &TM);

  // ParseSubtargetFeatures lives in MovGenSubtargetInfo.inc; this stub keeps
  // it callable from initializeSubtargetDependencies (and parses nothing yet).
  void ParseSubtargetFeatures(StringRef CPU, StringRef TuneCPU, StringRef FS);

  const MovInstrInfo       *getInstrInfo()       const override { return &InstrInfo; }
  const MovRegisterInfo    *getRegisterInfo()    const override { return &RegInfo; }
  const MovFrameLowering   *getFrameLowering()   const override { return &FrameLowering; }
  const MovTargetLowering  *getTargetLowering()  const override { return &TLInfo; }
  const SelectionDAGTargetInfo *getSelectionDAGInfo() const override {
    return &TSInfo;
  }

private:
  // Order matters: RegInfo is referenced by InstrInfo's constructor.
  MovRegisterInfo RegInfo;
  MovInstrInfo InstrInfo;
  MovFrameLowering FrameLowering;
  MovTargetLowering TLInfo;
  SelectionDAGTargetInfo TSInfo;
};
} // namespace llvm
