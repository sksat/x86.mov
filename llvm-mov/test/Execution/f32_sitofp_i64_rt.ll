; Stage 7h10 — sitofp i64→f32 + fptosi f32→i64 round-trip via
; __floatdisf + __fixsfdi. 42 fits exactly in 24-bit mantissa.

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i64 %v) {
  %f = sitofp i64 %v to float
  %r = fptosi float %f to i64
  %lo = trunc i64 %r to i32
  ret i32 %lo
}
