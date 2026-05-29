; Stage 7g1 — `fsub` via SDAG soft-float → `call __subsf3`. The
; injected `__subsf3` flips b's sign bit and delegates to `__addsf3`,
; so the test exercises both helpers in one shot.
;
; 3.5 - 1.5 = 2.0 → exponent byte = 0x80 = 128
;
;  3.5 = 0x40600000 = 1080033280
;  1.5 = 0x3FC00000 = 1069547520
;  2.0 = 0x40000000  →  exp byte 0x80

target triple = "mov-unknown-linux-gnu"

define i32 @fsub_exp(float %a, float %b) {
  %d    = fsub float %a, %b
  %bits = bitcast float %d to i32
  %s    = lshr i32 %bits, 23
  %r    = and i32 %s, 255
  ret i32 %r
}
