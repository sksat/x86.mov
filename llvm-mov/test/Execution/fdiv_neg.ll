; Stage 7g3 — sign handling. -6.0 / 2.0 = -3.0. The helper computes
; signR = signA XOR signB. Extract the sign bit.
;
;   -6.0 = 0xC0C00000 = 3233808384
;    2.0 = 0x40000000 = 1073741824
;   -3.0 = 0xC0400000  →  bit 31 = 1

target triple = "mov-unknown-linux-gnu"

define i32 @fdiv_sign(float %a, float %b) {
  %q    = fdiv float %a, %b
  %bits = bitcast float %q to i32
  %s    = lshr i32 %bits, 31
  ret i32 %s
}
