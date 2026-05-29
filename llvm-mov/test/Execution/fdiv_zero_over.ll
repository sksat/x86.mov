; Stage 7g3 — zero dividend. 0.0 / 3.0 = 0.0. The helper short-
; circuits on `ea == 0` to signed zero with sign sr = sa XOR sb.
; Catches a missing "a == 0" gate.
;
;   0.0 = 0
;   3.0 = 0x40400000 = 1077936128
;   result 0.0 → exp byte 0

target triple = "mov-unknown-linux-gnu"

define i32 @fdiv_exp(float %a, float %b) {
  %q    = fdiv float %a, %b
  %bits = bitcast float %q to i32
  %expA = lshr i32 %bits, 23
  %exp  = and i32 %expA, 255
  ret i32 %exp
}
