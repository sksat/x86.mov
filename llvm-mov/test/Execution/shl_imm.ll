; Stage-3 fixture: SHL32ri (immediate shift). 21 << 1 = 42.

target triple = "mov-unknown-linux-gnu"

define i32 @shl_one(i32 %x) {
  %r = shl i32 %x, 1
  ret i32 %r
}
