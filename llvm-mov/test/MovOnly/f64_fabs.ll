; Stage 7h12 mov-only assert for `llvm.fabs.f64`.

target triple = "mov-unknown-linux-gnu"

declare double @llvm.fabs.f64(double)

define double @fabs_passthrough(double %d) {
  %r = call double @llvm.fabs.f64(double %d)
  ret double %r
}
