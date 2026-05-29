; Stage 7h3 — fptosi from i64-bits input: 2.7_f64 → 2 (truncate
; toward zero).
;
;   2.7 = 0x4005999999999999 → lo = 0x99999999, hi = 0x40059999
;   ≈ 2.699999... → fptosi → 2

target triple = "mov-unknown-linux-gnu"

define i32 @fptosi_test(i64 %bits) {
  %d = bitcast i64 %bits to double
  %i = fptosi double %d to i32
  ret i32 %i
}
