; Stage 7b1 PoC fixture — bitwise AND, immediate (ri) form.
;
; `and i32 %x, 0xFF` is the typical "low-byte mask" pattern, which
; legalizeBitwise32ri rewrites into four per-byte table lookups
; against __mov_and8_table. Same prologue/epilogue + scratch layout
; as the ADD32 family.

target triple = "mov-unknown-linux-gnu"

define i32 @and_ri(i32 %x) {
  %r = and i32 %x, 255
  ret i32 %r
}
