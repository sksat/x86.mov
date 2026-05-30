; Stage 7h12 — fabs(float). fabs(-3.0) = 3.0 → fptosi → 3.

target triple = "mov-unknown-linux-gnu"

declare float @llvm.fabs.f32(float)

define i32 @rt(i32 %i) {
  %f = sitofp i32 %i to float
  %a = call float @llvm.fabs.f32(float %f)
  %j = fptosi float %a to i32
  ret i32 %j
}
