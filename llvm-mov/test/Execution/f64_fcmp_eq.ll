; Stage 7h2 — `fcmp oeq double` via SDAG soft-float → `call __eqdf2`.
; Helper returns 0 for equal-ordered; SDAG checks that against zero.
;
;   1.0_f64 == 1.0_f64 → true → returns 1

target triple = "mov-unknown-linux-gnu"

define i32 @fcmp_op_f64(i64 %ab, i64 %bb) {
  %a = bitcast i64 %ab to double
  %b = bitcast i64 %bb to double
  %r = fcmp oeq double %a, %b
  %z = zext i1 %r to i32
  ret i32 %z
}
