; Stage 7h11 mov-only assert for `llvm.ceil.f64`.

target triple = "mov-unknown-linux-gnu"

declare double @llvm.ceil.f64(double)

define double @ceil_passthrough(double %d) {
  %r = call double @llvm.ceil.f64(double %d)
  ret double %r
}
