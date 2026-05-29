; Stage 7g2 — multiplicative zero. anything * 0.0 = 0.0. Catches a
; missing "either operand is zero" short-circuit (without it, the
; helper would compute 0 << huge_exp and emit garbage).
;
;   1.5 = 0x3FC00000 = 1069547520
;   0.0 = 0
;   result 0.0 → exp byte 0

target triple = "mov-unknown-linux-gnu"

define i32 @fmul_exp(float %a, float %b) {
  %prod = fmul float %a, %b
  %bits = bitcast float %prod to i32
  %expA = lshr i32 %bits, 23
  %exp  = and i32 %expA, 255
  ret i32 %exp
}
