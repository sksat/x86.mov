; Stage 7h2 — fcmp oge: 2.0 >= 2.0 → true (routes through __gedf2,
; which has the negated-unord convention).

target triple = "mov-unknown-linux-gnu"

define i32 @fcmp_op_f64(i64 %ab, i64 %bb) {
  %a = bitcast i64 %ab to double
  %b = bitcast i64 %bb to double
  %r = fcmp oge double %a, %b
  %z = zext i1 %r to i32
  ret i32 %z
}
