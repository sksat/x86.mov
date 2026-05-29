; Stage 7g1 — `fcmp` correctly orders signed (negative) operands.
; -1.0 < -0.5 (more negative is smaller). The naive unsigned i32
; compare on the bit patterns would say -1.0 > -0.5 because |
; -1.0|'s bit pattern (0xBF800000) is larger than |-0.5|'s
; (0xBF000000). The injected helper uses the total-order key
; transformation (XOR with 0x7FFFFFFF for negatives) so signed
; integer compare matches float order.
;
; -1.0 = 0xBF800000 = 3212836864
; -0.5 = 0xBF000000 = 3204448256

target triple = "mov-unknown-linux-gnu"

define i32 @cmp(float %a, float %b) {
  %lt = fcmp olt float %a, %b
  %r  = select i1 %lt, i32 42, i32 7
  ret i32 %r
}
