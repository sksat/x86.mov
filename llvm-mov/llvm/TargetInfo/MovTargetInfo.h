//===-- MovTargetInfo.h -----------------------------------------*- C++ -*-===//
#pragma once

namespace llvm {
class Target;

// Singleton Target description registered with the LLVM TargetRegistry.
// Defined in MovTargetInfo.cpp; consumed by MCTargetDesc, the codegen
// library, and the LLVMInitializeMov* entry points.
Target &getTheMovTarget();
} // namespace llvm
