; Stage 7h2 — -0.0 == +0.0 should be true even though the bit
; patterns differ. The BothZero short-circuit in the compare body
; handles this.
;
;   -0.0 = 0x8000000000000000  (hi = 0x80000000)
;   +0.0 = 0

target triple = "mov-unknown-linux-gnu"

define i32 @fcmp_op_f64(i64 %ab, i64 %bb) {
  %a = bitcast i64 %ab to double
  %b = bitcast i64 %bb to double
  %r = fcmp oeq double %a, %b
  %z = zext i1 %r to i32
  ret i32 %z
}
