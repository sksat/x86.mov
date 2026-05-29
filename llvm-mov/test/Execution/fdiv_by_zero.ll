; Stage 7g3 — division by zero. 3.0 / 0.0 = +Inf. The helper
; short-circuits on `eb == 0` to signed infinity (exp byte 0xFF,
; mantissa 0). Catches a missing "b == 0" gate.
;
;   3.0 = 0x40400000 = 1077936128
;   0.0 = 0
;   result +Inf → exp byte 0xFF = 255

target triple = "mov-unknown-linux-gnu"

define i32 @fdiv_exp(float %a, float %b) {
  %q    = fdiv float %a, %b
  %bits = bitcast float %q to i32
  %expA = lshr i32 %bits, 23
  %exp  = and i32 %expA, 255
  ret i32 %exp
}
