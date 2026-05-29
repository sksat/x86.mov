; Stage 7h1 — +Inf survives f32 → f64 → f32 round-trip.
;
;   +Inf_f32 = 0x7F800000 = 2139095040
;   result f32 +Inf → (bits >> 22) & 0xFF = 0xFE = 254

target triple = "mov-unknown-linux-gnu"

define i32 @rt_top9(float %f) {
  %d = fpext float %f to double
  %r = fptrunc double %d to float
  %bits = bitcast float %r to i32
  %t    = lshr i32 %bits, 22
  %x    = and i32 %t, 255
  ret i32 %x
}
