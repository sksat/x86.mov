; Stage 7g1 — fadd identity over zero: a + 0 = a. The injected
; `__addsf3` must short-circuit when one operand has an exponent /
; mantissa of zero — otherwise we'd normalize a zero by shifting an
; all-zero significand left, which would either loop forever or
; produce a garbage exponent depending on how the normalize is gated.
;
; 1.0 + 0.0 = 1.0  →  bits = 0x3F800000  →  (bits >> 23) & 0xFF = 0x7F = 127

target triple = "mov-unknown-linux-gnu"

define i32 @fadd_exp(float %a, float %b) {
  %sum  = fadd float %a, %b
  %bits = bitcast float %sum to i32
  %expA = lshr i32 %bits, 23
  %exp  = and i32 %expA, 255
  ret i32 %exp
}
