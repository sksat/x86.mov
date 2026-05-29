; Stage 7h6 — multiplicative identity. 42 / 1 = 42. ma == mb at the
; initial renormalize (no shift, er stays).

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i32 %i, i32 %j) {
  %a = sitofp i32 %i to double
  %b = sitofp i32 %j to double
  %r = fdiv double %a, %b
  %x = fptosi double %r to i32
  ret i32 %x
}
