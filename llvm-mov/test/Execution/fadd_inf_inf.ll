; Stage 7g4 — Inf + Inf with same sign = Inf. Both operands are
; +Inf, the result is +Inf (preserved). The 7g1 path already
; produces signed-Inf for this via the exponent-overflow gate, but
; the new Inf-input override in 7g4 makes the contract explicit.
;
;   +Inf = 0x7F800000 = 2139095040
;   result = +Inf → (bits >> 22) & 0xFF = 0xFE = 254

target triple = "mov-unknown-linux-gnu"

define i32 @fop_naninf_byte(float %a, float %b) {
  %r    = fadd float %a, %b
  %bits = bitcast float %r to i32
  %top9 = lshr i32 %bits, 22
  %exp  = and i32 %top9, 255
  ret i32 %exp
}
