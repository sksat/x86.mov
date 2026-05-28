; Stage 7f2 — exercise the full 32-iter long division shifting bits
; in from the high end of the dividend. `udivide(0x12345678, 0x10000)`
; = 0x1234. We take the low byte (0x34 = 52) so a partial division
; bug that drops the top half of the dividend would surface as 0
; instead of 52.

target triple = "mov-unknown-linux-gnu"

define i32 @udivide(i32 %n, i32 %d) {
  %q = udiv i32 %n, %d
  %low = and i32 %q, 255
  ret i32 %low
}
