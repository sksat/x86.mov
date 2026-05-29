; Stage 7g3 — exercises the initial-renormalize path. 1.0 / 3.0 has
; ma = 0x800000 < mb = 0xC00000, so the helper shifts ma left by 1
; (ma_norm = 0x1000000) and decrements er by 1 before entering the
; long-division loop. The mantissa walks the classic 0.0101010… bit
; pattern, with rounding-up at the trailing 1.
;
;   1.0 = 0x3F800000 = 1065353216
;   3.0 = 0x40400000 = 1077936128
;   0.3333... = 0x3EAAAAAB  →  (bits >> 23) & 0xFF = 0x7D = 125

target triple = "mov-unknown-linux-gnu"

define i32 @fdiv_exp(float %a, float %b) {
  %q    = fdiv float %a, %b
  %bits = bitcast float %q to i32
  %expA = lshr i32 %bits, 23
  %exp  = and i32 %expA, 255
  ret i32 %exp
}
