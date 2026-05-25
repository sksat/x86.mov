; Stage-3.5 fixture: i16 formal argument + i16 return.
; Caller pushes 65578 = 0x1002A — low i16 = 0x002A = 42; the high i16
; word is non-zero so a missing TRUNCATE shows up at SDValue type-check.

target triple = "mov-unknown-linux-gnu"

define i16 @id16(i16 %x) {
  ret i16 %x
}
