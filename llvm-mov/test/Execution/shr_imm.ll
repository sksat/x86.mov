; Stage-3 fixture: SHR32ri (immediate logical-right shift). 84 >> 1 = 42.

target triple = "mov-unknown-linux-gnu"

define i32 @shr_one(i32 %x) {
  %r = lshr i32 %x, 1
  ret i32 %r
}
