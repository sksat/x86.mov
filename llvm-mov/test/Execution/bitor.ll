; Stage-3 fixture: OR32rr. bitor(0x28, 0x12) → 0x3A = 58... no — pick
; values whose OR is 42: 32 | 10 → 42 (no shared bits, no carry concern).

target triple = "mov-unknown-linux-gnu"

define i32 @bitor(i32 %a, i32 %b) {
  %r = or i32 %a, %b
  ret i32 %r
}
