; Stage 7h11 — round(float). round(1.5) = 2 (ties away from zero).

target triple = "mov-unknown-linux-gnu"

declare float @llvm.round.f32(float)

define i32 @rt(i32 %i) {
  %f = sitofp i32 %i to float
  %h = fadd float %f, 5.000000e-01
  %r = call float @llvm.round.f32(float %h)
  %j = fptosi float %r to i32
  ret i32 %j
}
