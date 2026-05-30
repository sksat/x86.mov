; Stage 7h12 mov-only assert for `llvm.copysign.f64`.

target triple = "mov-unknown-linux-gnu"

declare double @llvm.copysign.f64(double, double)

define double @copysign_passthrough(double %x, double %y) {
  %r = call double @llvm.copysign.f64(double %x, double %y)
  ret double %r
}
