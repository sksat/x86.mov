; Stage 7h1 — f32 → f64 → f32 round-trip preserves the value. The
; intermediate f64 has more precision than f32, so a normal-range
; f32 value extends losslessly and truncs back to itself.
;
;   6.0_f32 → 6.0_f64 → 6.0_f32 → exp byte 0x81 = 129

target triple = "mov-unknown-linux-gnu"

define i32 @rt_exp(float %f) {
  %d = fpext float %f to double
  %r = fptrunc double %d to float
  %bits = bitcast float %r to i32
  %expA = lshr i32 %bits, 23
  %exp  = and i32 %expA, 255
  ret i32 %exp
}
