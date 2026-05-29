; Stage 7h6 — initial renormalize path: 1 / 3 = 0.333... Mantissa
; needs the ma < mb shift before the long-division loop. fptosi
; truncates toward zero, so 0.333… → 0.

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i32 %i, i32 %j) {
  %a = sitofp i32 %i to double
  %b = sitofp i32 %j to double
  %r = fdiv double %a, %b
  %x = fptosi double %r to i32
  ret i32 %x
}
