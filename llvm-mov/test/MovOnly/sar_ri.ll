; Stage 7b2 PoC fixture — arithmetic (signed) right shift, mov-only.
;
; `ashr i32 %x, 4` covers the SAR32ri path: the prologue computes the
; sign byte (0x00 or 0xFF) from orig[3] via __mov_sar_sign_byte and
; stashes it in sign_buf. Every OOR high-side source byte in the
; chain pulls from sign_buf instead of zero.

target triple = "mov-unknown-linux-gnu"

define i32 @sar_ri(i32 %x) {
  %r = ashr i32 %x, 4
  ret i32 %r
}
