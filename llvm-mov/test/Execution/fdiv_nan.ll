; Stage 7g4 — NaN / finite = NaN.
;
;   qNaN = 0x7FC00000 = 2143289344
;   1.0  = 0x3F800000 = 1065353216
;   result = qNaN → 255

target triple = "mov-unknown-linux-gnu"

define i32 @fop_naninf_byte(float %a, float %b) {
  %r    = fdiv float %a, %b
  %bits = bitcast float %r to i32
  %top9 = lshr i32 %bits, 22
  %exp  = and i32 %top9, 255
  ret i32 %exp
}
