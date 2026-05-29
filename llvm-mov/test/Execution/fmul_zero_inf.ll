; Stage 7g4 — 0 * Inf = NaN (IEEE indeterminate). The 7g2 path
; short-circuited "either operand is zero" to signed zero, so this
; case previously returned 0 instead of NaN. The new "0 * Inf" gate
; overrides the zero short-circuit for Inf-bearing inputs.
;
;   0.0  = 0
;   +Inf = 0x7F800000 = 2139095040
;   result = qNaN → 255

target triple = "mov-unknown-linux-gnu"

define i32 @fop_naninf_byte(float %a, float %b) {
  %r    = fmul float %a, %b
  %bits = bitcast float %r to i32
  %top9 = lshr i32 %bits, 22
  %exp  = and i32 %top9, 255
  ret i32 %exp
}
