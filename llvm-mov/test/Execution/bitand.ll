; Stage-3 fixture: AND32rr. bitand(0xFE, 0x2B) → 0x2A = 42.

target triple = "mov-unknown-linux-gnu"

define i32 @bitand(i32 %a, i32 %b) {
  %r = and i32 %a, %b
  ret i32 %r
}
