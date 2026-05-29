; Stage 7h2 — sign-aware compare: -1.0 < 1.0 → true. Exercises the
; total-order key transform; without it a naive signed-i64 compare
; would treat -1.0 (= 0xBFF00000_00000000, sign + magnitude) as a
; large unsigned value and return false.

target triple = "mov-unknown-linux-gnu"

define i32 @fcmp_op_f64(i64 %ab, i64 %bb) {
  %a = bitcast i64 %ab to double
  %b = bitcast i64 %bb to double
  %r = fcmp olt double %a, %b
  %z = zext i1 %r to i32
  ret i32 %z
}
