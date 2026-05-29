; Stage 7h10 — large i64 that still fits exactly in f32. 1000000 =
; 0xF4240; below 2^24 = 16777216 so f32 is exact. Low byte = 0x40.

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i64 %v) {
  %f = sitofp i64 %v to float
  %r = fptosi float %f to i64
  %lo = trunc i64 %r to i32
  ret i32 %lo
}
