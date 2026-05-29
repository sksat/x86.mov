; Stage 7g4 — NaN propagation through fadd. NaN + finite = NaN.
; The 7g1 __addsf3 used to treat the NaN bit pattern as a normal
; Inf-magnitude number and produce a finite-Inf garbage output;
; this stage adds an explicit NaN-input gate that overrides the
; loop-body result with the canonical quiet NaN (0x7FC00000).
;
;   qNaN = 0x7FC00000 = 2143289344
;   1.0  = 0x3F800000 = 1065353216
;   result = qNaN → (bits >> 22) & 0xFF = 0x1FF & 0xFF = 0xFF = 255
;
; Extraction picks the "top 8 bits past bit 22", i.e. exp byte plus
; the quiet bit. Inf yields 0xFE (254); qNaN yields 0xFF (255).

target triple = "mov-unknown-linux-gnu"

define i32 @fop_naninf_byte(float %a, float %b) {
  %r    = fadd float %a, %b
  %bits = bitcast float %r to i32
  %top9 = lshr i32 %bits, 22
  %exp  = and i32 %top9, 255
  ret i32 %exp
}
