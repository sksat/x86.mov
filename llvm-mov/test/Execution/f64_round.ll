; Stage 7h11 — round(double): ties away from zero. round(1.5) = 2
; (positive tie rounds up). round(2.5) would also = 3 (not 2 — i.e.
; ties-away-from-zero, not ties-to-even).

target triple = "mov-unknown-linux-gnu"

declare double @llvm.round.f64(double)

define i32 @rt(i32 %i) {
  %d = sitofp i32 %i to double
  %h = fadd double %d, 5.000000e-01
  %r = call double @llvm.round.f64(double %h)
  %j = fptosi double %r to i32
  ret i32 %j
}
