; Stage 7h1 — sign bit preserved through fpext. -1.0_f32 →
; -1.0_f64 has sign bit = 1.
;
;   -1.0_f32 = 0xBF800000 = 3212836608
;   -1.0_f64 top = 0xBFF00000
;   (top >> 31) & 1 = 1

target triple = "mov-unknown-linux-gnu"

; See `f64_extend.ll` for the low/high XOR trick rationale. For
; `-1.0` the low 32 bits of the f64 are zero so XOR-mixing keeps
; the sign bit intact.
define i32 @ext_sign(float %f) {
  %d   = fpext float %f to double
  %b   = bitcast double %d to i64
  %lo  = trunc i64 %b to i32
  %hi64 = lshr i64 %b, 32
  %hi  = trunc i64 %hi64 to i32
  %mix = xor i32 %lo, %hi
  %s   = lshr i32 %mix, 31
  ret i32 %s
}
