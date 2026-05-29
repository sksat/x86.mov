; Stage 7h11 mov-only assert for `llvm.floor.f64`. Lowered to a call
; to `floor` (libm name); the helper body is injected by the driver.

target triple = "mov-unknown-linux-gnu"

declare double @llvm.floor.f64(double)

define double @floor_passthrough(double %d) {
  %r = call double @llvm.floor.f64(double %d)
  ret double %r
}
