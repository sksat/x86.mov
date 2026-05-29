; Stage 7g4 — opposite-sign Inf cancellation. +Inf + (-Inf) = NaN.
; This is the case the 7g1 __addsf3 used to mishandle: equal-
; magnitude opposite-sign operands hit the CancelZero gate and
; returned +0 instead of NaN. The new Inf-pair-opposite-sign gate
; overrides that.
;
;   +Inf = 0x7F800000 = 2139095040
;   -Inf = 0xFF800000 = 4286578688
;   result = qNaN → (bits >> 22) & 0xFF = 255

target triple = "mov-unknown-linux-gnu"

define i32 @fop_naninf_byte(float %a, float %b) {
  %r    = fadd float %a, %b
  %bits = bitcast float %r to i32
  %top9 = lshr i32 %bits, 22
  %exp  = and i32 %top9, 255
  ret i32 %exp
}
