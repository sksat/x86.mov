; Stage 7g1 — regression for codex-review P1 on equal-exponent
; opposite-sign subtraction. The naive "order by exponent only"
; routes operand A to m_large even when |B| > |A|, yielding an
; unsigned underflow inside the subtract and the wrong result sign.
;
; 1.0 + (-1.5) = -0.5. Both inputs have exponent 0x7F; mantissa of B
; (0x400000 + implicit-1) is larger than A's (0x000000 + implicit-1).
; The fixed implementation orders by *magnitude*, picks B as m_large,
; and produces sign = 1, exp = 0x7E (post-normalize), mantissa = 0.
; Bits = 0xBF000000 → exit byte (bits 24..31) = 0xBF = 191.
;
;  1.0 = 0x3F800000 = 1065353216
; -1.5 = 0xBFC00000 = 3217031168

target triple = "mov-unknown-linux-gnu"

define i32 @sign_exp(float %a, float %b) {
  %sum  = fadd float %a, %b
  %bits = bitcast float %sum to i32
  %shift = lshr i32 %bits, 24
  %byte  = and i32 %shift, 255
  ret i32 %byte
}
