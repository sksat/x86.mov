; Stage 7b2 PoC fixture — left shift by a constant, mov-only.
;
; `shl i32 %x, 2` exercises the SHL32ri legalize path: bit_shift = 2,
; byte_shift = 0, no whole-byte move special-case. The byte chain
; runs high-to-low, with each byte produced by ORing the low-side
; shl_byte_2 lookup with the high-side shr_byte_6 lookup.

target triple = "mov-unknown-linux-gnu"

define i32 @shl_ri(i32 %x) {
  %r = shl i32 %x, 2
  ret i32 %r
}
