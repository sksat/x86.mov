; Stage 7h3 — fptosi truncation on negative value: -3.5_f64 → -3
; (truncate toward zero, not floor; floor would give -4).
;
;   -3.5 = 0xC00C000000000000 → lo = 0, hi = 0xC00C0000
;   fptosi → -3 → exit code 253 (= 0xFD)

target triple = "mov-unknown-linux-gnu"

define i32 @fptosi_test(i64 %bits) {
  %d = bitcast i64 %bits to double
  %i = fptosi double %d to i32
  ret i32 %i
}
