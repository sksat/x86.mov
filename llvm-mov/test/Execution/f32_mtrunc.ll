; Stage 7h11 — math trunc(float). trunc(1.5) = 1.

target triple = "mov-unknown-linux-gnu"

declare float @llvm.trunc.f32(float)

define i32 @rt(i32 %i) {
  %f = sitofp i32 %i to float
  %h = fadd float %f, 5.000000e-01
  %r = call float @llvm.trunc.f32(float %h)
  %j = fptosi float %r to i32
  ret i32 %j
}
