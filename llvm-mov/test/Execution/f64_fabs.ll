; Stage 7h12 — fabs(double). fabs(-3.0) = 3.0 → fptosi → 3.

target triple = "mov-unknown-linux-gnu"

declare double @llvm.fabs.f64(double)

define i32 @rt(i32 %i) {
  %d = sitofp i32 %i to double
  %a = call double @llvm.fabs.f64(double %d)
  %j = fptosi double %a to i32
  ret i32 %j
}
