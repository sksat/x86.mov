; Stage 7h10 — uitofp u64→f32 + fptoui f32→u64 round-trip via
; __floatundisf + __fixunssfdi. Use 2^63 (high 32 = 0x80000000) —
; only one bit set, exactly representable in f32.
;
;   2^63 → low byte 0

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i64 %v) {
  %f = uitofp i64 %v to float
  %r = fptoui float %f to i64
  %lo = trunc i64 %r to i32
  %x = and i32 %lo, 255
  ret i32 %x
}
