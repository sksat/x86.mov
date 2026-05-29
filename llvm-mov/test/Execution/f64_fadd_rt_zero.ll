; Stage 7h4 — fadd with zero input. 0 + 42 = 42. Catches a missing
; "a == 0 ⇒ b" pass-through gate.

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i32 %i, i32 %j) {
  %a = sitofp i32 %i to double
  %b = sitofp i32 %j to double
  %r = fadd double %a, %b
  %x = fptosi double %r to i32
  ret i32 %x
}
