; Stage 7g2 — fmul that exercises the "carry-out" normalize step:
; 3.0 * 3.0 = 9.0.
;
; 3.0 in IEEE single has mantissa 1.1 (binary) = 0xC00000 with the
; implicit one. Squaring gives 0b10.01 ⇒ the 48-bit product has
; its MSB at bit 47, not bit 46 (the "small product" path). The
; helper body's case-A branch handles this: shift the kept mantissa
; one extra position right and bump the result exponent by 1.
;
;   3.0 = 0x40400000 = 1077936128
;   9.0 = 0x41100000  →  (bits >> 23) & 0xFF = 0x82 = 130

target triple = "mov-unknown-linux-gnu"

define i32 @fmul_exp(float %a, float %b) {
  %prod = fmul float %a, %b
  %bits = bitcast float %prod to i32
  %expA = lshr i32 %bits, 23
  %exp  = and i32 %expA, 255
  ret i32 %exp
}
