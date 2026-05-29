; Stage 7h2 — fcmp uno with NaN input. uno = "unordered", returns
; true if either operand is NaN. Routes through __unorddf2.

target triple = "mov-unknown-linux-gnu"

define i32 @fcmp_op_f64(i64 %ab, i64 %bb) {
  %a = bitcast i64 %ab to double
  %b = bitcast i64 %bb to double
  %r = fcmp uno double %a, %b
  %z = zext i1 %r to i32
  ret i32 %z
}
