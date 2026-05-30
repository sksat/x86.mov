; Stage 7h12 — copysign(-3.0, 1.0) = 3.0. Verifies the input's sign
; gets cleared (not just OR-ed with the second arg's sign bit).

target triple = "mov-unknown-linux-gnu"

declare double @llvm.copysign.f64(double, double)

define i32 @rt(i32 %a, i32 %b) {
  %x = sitofp i32 %a to double
  %y = sitofp i32 %b to double
  %s = call double @llvm.copysign.f64(double %x, double %y)
  %j = fptosi double %s to i32
  ret i32 %j
}
