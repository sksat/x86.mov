; Stage-3.5 regression fixture (codex P1 review of dd03f16):
; signed narrow ints triggered `sign_extend_inreg` SDNodes which we
; couldn't select (no movsx). After setting SIGN_EXTEND_INREG to Expand,
; the legalizer rewrites them into `shl N; sar N`, which our existing
; SHL32ri/SAR32ri instructions handle.
;
; sext i8 -42 (= 0xD6) → i32 0xFFFFFFD6 = -42. mask with 0xFF =
; 0xD6 = 214 (the exit code wraps the negative). So expected = 214.

target triple = "mov-unknown-linux-gnu"

define i32 @sext_i8(i8 %x) {
  %y = sext i8 %x to i32
  %r = and i32 %y, 255
  ret i32 %r
}
