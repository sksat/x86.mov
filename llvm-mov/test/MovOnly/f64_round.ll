; Stage 7h11 mov-only assert for `llvm.round.f64`.

target triple = "mov-unknown-linux-gnu"

declare double @llvm.round.f64(double)

define double @round_passthrough(double %d) {
  %r = call double @llvm.round.f64(double %d)
  ret double %r
}
