; Stage 7g3 — multiplicative identity. x / 1.0 = x. Verifies the
; helper preserves the exponent and mantissa for a clean case where
; the long-division loop walks 23 iters all yielding the original
; mantissa bits, leaving q == ma and er == ea.
;
;   4.5 = 0x40900000 = 1083179008  →  exp byte 0x81 = 129
;   1.0 = 0x3F800000 = 1065353216

target triple = "mov-unknown-linux-gnu"

define i32 @fdiv_exp(float %a, float %b) {
  %q    = fdiv float %a, %b
  %bits = bitcast float %q to i32
  %expA = lshr i32 %bits, 23
  %exp  = and i32 %expA, 255
  ret i32 %exp
}
