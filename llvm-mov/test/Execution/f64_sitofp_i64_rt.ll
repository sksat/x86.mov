; Stage 7h9 — sitofp i64→f64 + fptosi f64→i64 round-trip via
; __floatdidf + __fixdfdi. 42 fits exactly in 53-bit mantissa.

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i64 %v) {
  %d = sitofp i64 %v to double
  %r = fptosi double %d to i64
  %lo = trunc i64 %r to i32
  ret i32 %lo
}
