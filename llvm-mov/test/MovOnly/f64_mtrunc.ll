; Stage 7h11 mov-only assert for `llvm.trunc.f64` (math trunc).

target triple = "mov-unknown-linux-gnu"

declare double @llvm.trunc.f64(double)

define double @mtrunc_passthrough(double %d) {
  %r = call double @llvm.trunc.f64(double %d)
  ret double %r
}
