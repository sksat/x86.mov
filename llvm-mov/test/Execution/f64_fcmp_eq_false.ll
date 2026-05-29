; Stage 7h2 — 1.0 != 2.0 → fcmp oeq returns false.

target triple = "mov-unknown-linux-gnu"

define i32 @fcmp_op_f64(i64 %ab, i64 %bb) {
  %a = bitcast i64 %ab to double
  %b = bitcast i64 %bb to double
  %r = fcmp oeq double %a, %b
  %z = zext i1 %r to i32
  ret i32 %z
}
