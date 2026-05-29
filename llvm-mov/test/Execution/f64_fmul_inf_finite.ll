; Stage 7h5 — Inf × finite = signed Inf. +Inf × 2.0 = +Inf → 254.

target triple = "mov-unknown-linux-gnu"

define i32 @nan_check(i64 %ab, i64 %bb) {
  %a = bitcast i64 %ab to double
  %b = bitcast i64 %bb to double
  %r = fmul double %a, %b
  %bits = bitcast double %r to i64
  %lo = trunc i64 %bits to i32
  %hi64 = lshr i64 %bits, 32
  %hi = trunc i64 %hi64 to i32
  %mix = xor i32 %lo, %hi
  %t = lshr i32 %mix, 19
  %x = and i32 %t, 255
  ret i32 %x
}
