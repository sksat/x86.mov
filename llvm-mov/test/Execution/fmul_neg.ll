; Stage 7g2 — sign handling. -2.0 * 3.0 = -6.0. The helper computes
; signR = signA XOR signB. Extract the sign bit.
;
;   -2.0 = 0xC0000000 = 3221225472
;    3.0 = 0x40400000 = 1077936128
;   -6.0 = 0xC0C00000  →  bit 31 = 1

target triple = "mov-unknown-linux-gnu"

define i32 @fmul_sign(float %a, float %b) {
  %prod = fmul float %a, %b
  %bits = bitcast float %prod to i32
  %s    = lshr i32 %bits, 31
  ret i32 %s
}
