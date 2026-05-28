; Stage 7f — exercise the multi-byte carry chain by multiplying two
; values whose product spans all 4 bytes of the result. Returns one
; of the higher bytes so the test value depends on inter-byte carry
; propagation, not just byte 0.
;
;   multiply(0x10001, 0x10001) = 0x100020001
;   low 32 bits = 0x00020001
;   (r >> 16) & 0xFF = 0x02
;
; If the carry chain at byte 2 doesn't propagate properly, this byte
; comes out wrong.

target triple = "mov-unknown-linux-gnu"

define i32 @multiply(i32 %a, i32 %b) {
  %r = mul i32 %a, %b
  %hi = lshr i32 %r, 16
  %hi_byte = and i32 %hi, 255
  ret i32 %hi_byte
}
