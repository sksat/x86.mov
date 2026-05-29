; Stage 7g2 — multiplicative identity. x * 1.0 = x. Verifies the
; helper preserves the exponent for a clean mantissa-times-implicit-
; 1 case (mantissa stays in case B, no rounding bits set).
;
;   4.5 = 0x40900000 = 1083179008  → exp byte 0x81 = 129
;   1.0 = 0x3F800000 = 1065353216

target triple = "mov-unknown-linux-gnu"

define i32 @fmul_exp(float %a, float %b) {
  %prod = fmul float %a, %b
  %bits = bitcast float %prod to i32
  %expA = lshr i32 %bits, 23
  %exp  = and i32 %expA, 255
  ret i32 %exp
}
