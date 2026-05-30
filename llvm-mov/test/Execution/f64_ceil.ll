; Stage 7h11 — ceil(1.5) = 2.

target triple = "mov-unknown-linux-gnu"

declare double @llvm.ceil.f64(double)

define i32 @rt(i32 %i) {
  %d = sitofp i32 %i to double
  %h = fadd double %d, 5.000000e-01
  %r = call double @llvm.ceil.f64(double %h)
  %j = fptosi double %r to i32
  ret i32 %j
}
