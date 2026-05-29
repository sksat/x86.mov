; Stage 7h11 — trunc(-1.5) = -1 (low byte 0xFF = 255). Distinguishes
; trunc from floor for negative inputs.

target triple = "mov-unknown-linux-gnu"

declare double @llvm.trunc.f64(double)

define i32 @rt(i32 %i) {
  %d = sitofp i32 %i to double
  %h = fadd double %d, 5.000000e-01
  %r = call double @llvm.trunc.f64(double %h)
  %j = fptosi double %r to i32
  %x = and i32 %j, 255
  ret i32 %x
}
