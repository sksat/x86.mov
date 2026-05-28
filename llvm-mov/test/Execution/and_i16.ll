; Stage-3.5 fixture: i16 bitwise. 0xFFFA & 0x002A = 0x002A = 42.
; Confirms narrow-int arithmetic compiles AND the result truncates back
; correctly across the i16 ABI return slot.

target triple = "mov-unknown-linux-gnu"

define i16 @and_i16(i16 %a, i16 %b) {
  %r = and i16 %a, %b
  ret i16 %r
}
