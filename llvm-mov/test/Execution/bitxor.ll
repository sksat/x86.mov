; Stage-3 fixture: XOR32rr. 63 ^ 21 = 0x3F ^ 0x15 = 0x2A = 42.

target triple = "mov-unknown-linux-gnu"

define i32 @bitxor(i32 %a, i32 %b) {
  %r = xor i32 %a, %b
  ret i32 %r
}
