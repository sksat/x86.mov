; Stage 7h12 — copysign(double, double). copysign(3.0, -1.0) = -3.0.
; fptosi → -3 → low byte 0xFD = 253.

target triple = "mov-unknown-linux-gnu"

declare double @llvm.copysign.f64(double, double)

define i32 @rt(i32 %a, i32 %b) {
  %x = sitofp i32 %a to double
  %y = sitofp i32 %b to double
  %s = call double @llvm.copysign.f64(double %x, double %y)
  %j = fptosi double %s to i32
  %z = and i32 %j, 255
  ret i32 %z
}
