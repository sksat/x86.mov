; Stage 7g1 — fadd with opposite signs and unequal magnitudes hits
; the subtract path with required left-normalization: 1.5 + (-0.5)
; = 1.0 needs the result to drop 1 binary place (mantissa goes from
; 0x800000 down to 0x800000 after one normalize-left). Exponent byte
; of 1.0 is 0x7F = 127.
;
;  1.5 = 0x3FC00000 = 1069547520
; -0.5 = 0xBF000000 = 3204448256

target triple = "mov-unknown-linux-gnu"

define i32 @fadd_exp(float %a, float %b) {
  %sum  = fadd float %a, %b
  %bits = bitcast float %sum to i32
  %expA = lshr i32 %bits, 23
  %exp  = and i32 %expA, 255
  ret i32 %exp
}
