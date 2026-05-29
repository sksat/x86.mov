; Stage 7g4 — finite + Inf = Inf. The 7g1 path already handles this
; via exp-overflow; the explicit Inf-input override makes the sign
; come from the Inf operand regardless of the finite side.
;
;   1.0  = 0x3F800000 = 1065353216
;   +Inf = 0x7F800000 = 2139095040
;   result = +Inf → 254

target triple = "mov-unknown-linux-gnu"

define i32 @fop_naninf_byte(float %a, float %b) {
  %r    = fadd float %a, %b
  %bits = bitcast float %r to i32
  %top9 = lshr i32 %bits, 22
  %exp  = and i32 %top9, 255
  ret i32 %exp
}
