; Stage 7c2 PoC fixture — mirror of is_42 exercising the EQ→JE path
; (here the `cmp eq` is paired with JE in the lowered shape, taking
; the opposite Jcc direction). Verifies that the IsEQ branch in
; legalizeCmpJccPairs correctly inverts the mask via XOR with 0xFF.

target triple = "mov-unknown-linux-gnu"

define i32 @is_not_42(i32 %x) {
  %c = icmp ne i32 %x, 42
  br i1 %c, label %ne, label %eq
ne:
  ret i32 1
eq:
  ret i32 0
}
