; Stage 7h1 — +0.0_f32 extends to +0.0_f64 (all bits zero).
;
;   0.0_f32 = 0
;   0.0_f64 = 0
;   (top >> 19) & 0xFF = 0

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
