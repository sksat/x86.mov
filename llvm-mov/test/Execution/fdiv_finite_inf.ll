; Stage 7g4 — finite / Inf = signed zero with sr.
;
;    2.0 = 0x40000000 = 1073741824
;   +Inf = 0x7F800000 = 2139095040
;   result = +0.0 → 0

target triple = "mov-unknown-linux-gnu"

define i32 @fop_naninf_byte(float %a, float %b) {
  %r    = fdiv float %a, %b
  %bits = bitcast float %r to i32
  %top9 = lshr i32 %bits, 22
  %exp  = and i32 %top9, 255
  ret i32 %exp
}
