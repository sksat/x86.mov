; Stage 7h1 — NaN survives f32 → f64 → f32 round-trip. fpext makes
; an f64 NaN; fptrunc collapses it back to canonical f32 qNaN.
;
;   qNaN_f32 = 0x7FC00000 = 2143289344
;   result f32 qNaN → (bits >> 22) & 0xFF = 0xFF = 255

target triple = "mov-unknown-linux-gnu"

define i32 @rt_top9(float %f) {
  %d = fpext float %f to double
  %r = fptrunc double %d to float
  %bits = bitcast float %r to i32
  %t    = lshr i32 %bits, 22
  %x    = and i32 %t, 255
  ret i32 %x
}
