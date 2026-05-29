; Stage 7g1 — fadd that needs normalize: 1.5 + 1.5 = 3.0. Same
; exponent (127) on both sides means the aligned mantissas add
; without right-shifting either; the sum mantissa (with the implicit
; ones included) is 0x1800000 (= 1.5 + 1.5 in significand form),
; which is one bit too wide and must be shifted right by 1 with
; result_exp incremented to 128. Catches a missing carry-out
; normalize step.
;
; 1.5 = 0x3FC00000 = 1069547520
; 3.0 = 0x40400000  →  exponent byte = 0x80 = 128

target triple = "mov-unknown-linux-gnu"

define i32 @fadd_exp(float %a, float %b) {
  %sum  = fadd float %a, %b
  %bits = bitcast float %sum to i32
  %expA = lshr i32 %bits, 23
  %exp  = and i32 %expA, 255
  ret i32 %exp
}
