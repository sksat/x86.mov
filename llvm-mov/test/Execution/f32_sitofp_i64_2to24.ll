; Stage 7h10 — 2^24 boundary, exactly representable in f32 (24-bit
; mantissa). Above this, even i32 values lose precision.

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i64 %v) {
  %f = sitofp i64 %v to float
  %r = fptosi float %f to i64
  %lo = trunc i64 %r to i32
  ret i32 %lo
}
