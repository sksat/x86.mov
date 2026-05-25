; Stage-3.5 fixture: variable-amount logical-right shift. lshr_reg(84, 1) = 42.

target triple = "mov-unknown-linux-gnu"

define i32 @lshr_reg(i32 %x, i32 %n) {
  %r = lshr i32 %x, %n
  ret i32 %r
}
