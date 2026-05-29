; Stage 7h11 — exercises the IsBelowOne path. rt(0) computes
; ceil(0 + 0.5) = ceil(0.5) = 1. Verifies that the f32 helper
; doesn't poison the result when exp < bias (codex-review P1:
; FracBits underflows the [0, 31] window, and the stage-7c1
; select-to-bit-blend rewrite would propagate the resulting `shl`
; poison without the FracBits & 31 clamp).

target triple = "mov-unknown-linux-gnu"

declare float @llvm.ceil.f32(float)

define i32 @rt(i32 %i) {
  %f = sitofp i32 %i to float
  %h = fadd float %f, 5.000000e-01
  %r = call float @llvm.ceil.f32(float %h)
  %j = fptosi float %r to i32
  ret i32 %j
}
