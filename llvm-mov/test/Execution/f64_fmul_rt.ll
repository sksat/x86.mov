; Stage 7h5 — fmul double round-trip via sitofp + fmul + fptosi.
; 6 × 7 = 42. Verifies __floatsidf + __muldf3 + __fixdfsi together.

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i32 %i, i32 %j) {
  %a = sitofp i32 %i to double
  %b = sitofp i32 %j to double
  %r = fmul double %a, %b
  %x = fptosi double %r to i32
  ret i32 %x
}
