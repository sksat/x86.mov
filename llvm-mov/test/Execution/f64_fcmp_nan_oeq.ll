; Stage 7h2 — fcmp oeq with NaN input. oeq returns false for any
; NaN comparison (the "ordered" prefix excludes unordered cases).
;
;   qNaN = 0x7FF8000000000000  (hi = 0x7FF80000)
;   1.0  = 0x3FF0000000000000

target triple = "mov-unknown-linux-gnu"

define i32 @fcmp_op_f64(i64 %ab, i64 %bb) {
  %a = bitcast i64 %ab to double
  %b = bitcast i64 %bb to double
  %r = fcmp oeq double %a, %b
  %z = zext i1 %r to i32
  ret i32 %z
}
