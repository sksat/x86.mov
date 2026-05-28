; Stage 7g1 — same-sign add but both negative: (-1.0) + (-2.0) =
; -3.0. The sign of the result is sign_a (== sign_b == 1), and the
; magnitudes add. Check the sign+exp byte = 0xC0 (= 192) via shifting
; out the mantissa and reading bits 23..30+31.
;
; -1.0 = 0xBF800000 = 3212836864
; -2.0 = 0xC0000000 = 3221225472
; -3.0 = 0xC0400000  →  (bits >> 23) = 0x180 (low byte 0x80, sign+exp
;                       = 0x80 | (0x80 ^ 0x80) … wait: full byte at
;                       bits 23..30 = 128, plus sign bit at 31 = 1.
;                       Easier: return bits >> 24, mask to 8 bits =
;                       0xC0 = 192.

target triple = "mov-unknown-linux-gnu"

define i32 @sign_exp(float %a, float %b) {
  %sum  = fadd float %a, %b
  %bits = bitcast float %sum to i32
  %shift = lshr i32 %bits, 24
  %byte  = and i32 %shift, 255
  ret i32 %byte
}
