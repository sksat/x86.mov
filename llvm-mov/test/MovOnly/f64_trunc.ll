; Stage 7h1 mov-only assert for `fptrunc f64 to f32`. Same as
; f64_extend but in the other direction.

target triple = "mov-unknown-linux-gnu"

define float @trunc_passthrough(double %d) {
  %f = fptrunc double %d to float
  ret float %f
}
