; Stage-3.5 fixture: variable-amount arithmetic-right shift. ashr_reg(168, 2) = 42.

target triple = "mov-unknown-linux-gnu"

define i32 @ashr_reg(i32 %x, i32 %n) {
  %r = ashr i32 %x, %n
  ret i32 %r
}
