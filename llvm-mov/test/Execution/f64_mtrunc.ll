; Stage 7h11 — math trunc(double): round toward zero. Distinct from
; the existing f64_trunc_{inf,nan,neg} fixtures which test fpext+
; fptrunc round-trip. trunc(1.5) = 1.

target triple = "mov-unknown-linux-gnu"

declare double @llvm.trunc.f64(double)

define i32 @rt(i32 %i) {
  %d = sitofp i32 %i to double
  %h = fadd double %d, 5.000000e-01
  %r = call double @llvm.trunc.f64(double %h)
  %j = fptosi double %r to i32
  ret i32 %j
}
