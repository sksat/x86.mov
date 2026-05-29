; Stage 7g1 — sitofp + fptosi round-trip for a value in the lossless
; range. Catches sign-handling bugs in either direction.
;
; (i32)-5 → -5.0 → (i32)-5 → low byte 0xFB = 251.

target triple = "mov-unknown-linux-gnu"

define i32 @round_trip(i32 %i) {
  %f = sitofp i32 %i to float
  %r = fptosi float %f to i32
  %low = and i32 %r, 255
  ret i32 %low
}
