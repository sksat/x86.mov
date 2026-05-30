; Stage 7h11 — round(-1.5) = -2 (ties away from zero). Low byte 0xFE
; = 254.

target triple = "mov-unknown-linux-gnu"

declare double @llvm.round.f64(double)

define i32 @rt(i32 %i) {
  %d = sitofp i32 %i to double
  %h = fadd double %d, 5.000000e-01
  %r = call double @llvm.round.f64(double %h)
  %j = fptosi double %r to i32
  %x = and i32 %j, 255
  ret i32 %x
}
