//===-- MovMCTargetDesc.h ---------------------------------------*- C++ -*-===//
#pragma once

#include "llvm/Support/DataTypes.h"

// Pull in TableGen-generated MC layer descriptors (instruction enums,
// register enums, subtarget feature bits) — these are needed by both this
// header's clients and the codegen library, so they're exposed here.
#define GET_REGINFO_ENUM
#include "MovGenRegisterInfo.inc"

#define GET_INSTRINFO_ENUM
#define GET_INSTRINFO_MC_HELPER_DECLS
#include "MovGenInstrInfo.inc"

#define GET_SUBTARGETINFO_ENUM
#include "MovGenSubtargetInfo.inc"
