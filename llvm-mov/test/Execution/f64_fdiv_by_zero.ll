; Stage 7h6 — 3 / 0 = +Inf. Check top 9 bits (exp byte + quiet bit):
; Inf → 254, qNaN → 255. Expect 254.

target triple = "mov-unknown-linux-gnu"

define i32 @by_zero(i64 %ab, i64 %bb) {
  %a = bitcast i64 %ab to double
  %b = bitcast i64 %bb to double
  %r = fdiv double %a, %b
  %bits = bitcast double %r to i64
  %lo = trunc i64 %bits to i32
  %hi64 = lshr i64 %bits, 32
  %hi = trunc i64 %hi64 to i32
  %mix = xor i32 %lo, %hi
  %t = lshr i32 %mix, 19
  %x = and i32 %t, 255
  ret i32 %x
}
