; Stage 7g1 — fadd exact cancellation: 1.0 + (-1.0) = +0.0. Opposite
; signs with identical magnitudes test the "if mant_a == mant_b after
; alignment, return +0 immediately" path. Without it, the result
; would carry whichever sign survived the subtract direction (UB
; without a special-case).
;
;  1.0 = 0x3F800000 = 1065353216
; -1.0 = 0xBF800000 = 3212836864
;  0.0 = 0x00000000  →  full result (not just exp byte) checked

target triple = "mov-unknown-linux-gnu"

; Return the low 24 bits OR'd with bits 23..30, plus sign bit shifted
; to bit 0. For +0.0 this is 0. Any non-zero result fails the test.
define i32 @fadd_is_zero(float %a, float %b) {
  %sum  = fadd float %a, %b
  %bits = bitcast float %sum to i32
  ; Collapse sign+exp+mantissa into one byte at LSB: nonzero ↔ result
  ; ≠ +0.0. Use a folded OR of all four bytes.
  %b0 = and i32 %bits, 255
  %s1 = lshr i32 %bits, 8
  %b1 = and i32 %s1, 255
  %s2 = lshr i32 %bits, 16
  %b2 = and i32 %s2, 255
  %s3 = lshr i32 %bits, 24
  %b3 = and i32 %s3, 255
  %o1 = or i32 %b0, %b1
  %o2 = or i32 %o1, %b2
  %o3 = or i32 %o2, %b3
  ret i32 %o3
}
