//===-- MovFrameLowering.cpp ----------------------------------------------===//
//
// Stage 0 has no prologue/epilogue work — everything is declared in the
// header. This .cpp exists so CMake can link MovFrameLowering as a unit
// and so later stages have a place to grow the body without churn in the
// component library's source list.
//
//===----------------------------------------------------------------------===//

#include "MovFrameLowering.h"
