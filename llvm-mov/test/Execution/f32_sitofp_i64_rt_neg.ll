; Stage 7h10 — negative round-trip via signed path.
;   v = (i64) -5 ; rt = -5 ; low byte = 0xFB = 251

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i64 %v) {
  %f = sitofp i64 %v to float
  %r = fptosi float %f to i64
  %lo = trunc i64 %r to i32
  %x = and i32 %lo, 255
  ret i32 %x
}
