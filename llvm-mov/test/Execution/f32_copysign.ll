; Stage 7h12 — copysign(float, float). copysign(3.0, -1.0) = -3.0.
; fptosi → -3 → low byte 0xFD = 253.

target triple = "mov-unknown-linux-gnu"

declare float @llvm.copysign.f32(float, float)

define i32 @rt(i32 %a, i32 %b) {
  %x = sitofp i32 %a to float
  %y = sitofp i32 %b to float
  %s = call float @llvm.copysign.f32(float %x, float %y)
  %j = fptosi float %s to i32
  %z = and i32 %j, 255
  ret i32 %z
}
