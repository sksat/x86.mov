; Stage 7h4 — fadd with opposite-sign operands. -3 + 5 = 2.
; Tests the diff-sign m_large - m_small path.

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i32 %i, i32 %j) {
  %a = sitofp i32 %i to double
  %b = sitofp i32 %j to double
  %r = fadd double %a, %b
  %x = fptosi double %r to i32
  ret i32 %x
}
