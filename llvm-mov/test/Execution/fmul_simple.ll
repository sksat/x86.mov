; Stage 7g2 — `fmul float` via SDAG Expand → `call __mulsf3`, whose
; body is injected by the llvm-mov-llc driver as IR.
;
; fmul 2.0 * 3.0 = 6.0. The exponent byte of 6.0 (IEEE-754 single)
; is 0x81 (= 129). 2 + 2 = 4, biased = 131; significand is in
; [2^46, 2^47) so the normalize-right step picks the "bit 46" path
; (case B in the helper body) and the result_exp stays at 131 −
; rounding shift = 129. Mantissa goes through the 24x24 → 48-bit
; multiply with no rounding loss.
;
;   2.0 = 0x40000000 = 1073741824
;   3.0 = 0x40400000 = 1077936128
;   6.0 = 0x40C00000  →  (bits >> 23) & 0xFF = 0x81 = 129

target triple = "mov-unknown-linux-gnu"

define i32 @fmul_exp(float %a, float %b) {
  %prod = fmul float %a, %b
  %bits = bitcast float %prod to i32
  %expA = lshr i32 %bits, 23
  %exp  = and i32 %expA, 255
  ret i32 %exp
}
