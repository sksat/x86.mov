; Stage 7h1 — sign bit survives the round-trip. -2.0_f32 round-trips.
;
;   -2.0_f32 = 0xC0000000 = 3221225472
;   result sign bit = 1

target triple = "mov-unknown-linux-gnu"

define i32 @rt_sign(float %f) {
  %d = fpext float %f to double
  %r = fptrunc double %d to float
  %bits = bitcast float %r to i32
  %s    = lshr i32 %bits, 31
  ret i32 %s
}
