; Stage 7g3 — `fdiv float` via SDAG Expand → `call __divsf3`, whose
; body is injected by the llvm-mov-llc driver as IR.
;
; fdiv 6.0 / 2.0 = 3.0. The exponent byte of 3.0 (IEEE-754 single)
; is 0x80 (= 128). ma = mb after the initial normalize since both
; mantissas have only the implicit-1 bit set; the long-division
; loop walks 23 iters with `r == 0` throughout, leaving q = 0x800000
; (the implicit-1 alone) and er = ea - eb + 127 = 128.
;
;   6.0 = 0x40C00000 = 1086324736
;   2.0 = 0x40000000 = 1073741824
;   3.0 = 0x40400000  →  (bits >> 23) & 0xFF = 0x80 = 128

target triple = "mov-unknown-linux-gnu"

define i32 @fdiv_exp(float %a, float %b) {
  %q    = fdiv float %a, %b
  %bits = bitcast float %q to i32
  %expA = lshr i32 %bits, 23
  %exp  = and i32 %expA, 255
  ret i32 %exp
}
