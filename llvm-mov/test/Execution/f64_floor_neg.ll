; Stage 7h11 — floor(-1.5) = -2 (low byte 0xFE = 254). Negative
; non-integer is where floor and trunc diverge.

target triple = "mov-unknown-linux-gnu"

declare double @llvm.floor.f64(double)

define i32 @rt(i32 %i) {
  %d = sitofp i32 %i to double
  %h = fadd double %d, 5.000000e-01
  %r = call double @llvm.floor.f64(double %h)
  %j = fptosi double %r to i32
  %x = and i32 %j, 255
  ret i32 %x
}
