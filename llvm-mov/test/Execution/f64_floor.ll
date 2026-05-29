; Stage 7h11 — floor(double).
;   d = (double)i + 0.5
;   floor(1.5) = 1, floor(-1.5) = -2, floor(0.5) = 0, floor(-0.5) = -1
; rt(i) = (i32) floor(i + 0.5)

target triple = "mov-unknown-linux-gnu"

declare double @llvm.floor.f64(double)

define i32 @rt(i32 %i) {
  %d = sitofp i32 %i to double
  %h = fadd double %d, 5.000000e-01
  %r = call double @llvm.floor.f64(double %h)
  %j = fptosi double %r to i32
  ret i32 %j
}
