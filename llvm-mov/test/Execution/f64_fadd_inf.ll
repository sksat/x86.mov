; Stage 7h4 — Inf preservation: +Inf + 1.0 = +Inf. Top 9 bits = 0xFE.
;
;   +Inf_f64 = 0x7FF0000000000000 (hi = 0x7FF00000)
;   1.0_f64  = 0x3FF0000000000000

target triple = "mov-unknown-linux-gnu"

define i32 @inf_check(i64 %ab, i64 %bb) {
  %a = bitcast i64 %ab to double
  %b = bitcast i64 %bb to double
  %r = fadd double %a, %b
  %bits = bitcast double %r to i64
  %lo = trunc i64 %bits to i32
  %hi64 = lshr i64 %bits, 32
  %hi = trunc i64 %hi64 to i32
  %mix = xor i32 %lo, %hi
  %t = lshr i32 %mix, 19
  %x = and i32 %t, 255
  ret i32 %x
}
