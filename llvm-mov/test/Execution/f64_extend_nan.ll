; Stage 7h1 — NaN propagation through fpext. f32 qNaN extends to
; an f64 NaN (exp = 0x7FF, mant != 0). Quiet bit position differs
; (f32 bit 22, f64 bit 51), so the helper has to shift the mantissa
; into the new field while preserving NaN-ness.
;
;   qNaN_f32 = 0x7FC00000 = 2143289344
;   expected f64 = 0x7FF8000000000000  → top 32 = 0x7FF80000
;   (top >> 19) & 0xFF = 0xFFF & 0xFF = 0xFF = 255

target triple = "mov-unknown-linux-gnu"

; See `f64_extend.ll` for the low/high XOR trick rationale.
define i32 @ext_top9(float %f) {
  %d   = fpext float %f to double
  %b   = bitcast double %d to i64
  %lo  = trunc i64 %b to i32
  %hi64 = lshr i64 %b, 32
  %hi  = trunc i64 %hi64 to i32
  %mix = xor i32 %lo, %hi
  %t   = lshr i32 %mix, 19
  %x   = and i32 %t, 255
  ret i32 %x
}
