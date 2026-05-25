; Stage-3 fixture: SUB32rr. sub(50, 8) → 42. Non-commutative — operand
; order matters and tests that ($src1 = $dst) tie holds for non-comm ops.

target triple = "mov-unknown-linux-gnu"

define i32 @sub(i32 %a, i32 %b) {
  %r = sub i32 %a, %b
  ret i32 %r
}
