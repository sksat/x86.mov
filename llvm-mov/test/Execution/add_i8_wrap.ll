; Stage-3.5 fixture: i8 add with wrap-around. 250 + 10 = 260, low byte
; = 4. Codex's stage-3.5 review specifically asked for this case to
; catch "promoted to i32, forgot to truncate the *return* value back to
; the narrow VT". If we ANY_EXTEND a wrap-already i8 back to i32 the
; low byte is still 4; if we somehow returned a full i32 260 the low
; byte is also 4, so the exit-code test alone can't distinguish — but
; without the right ANY_EXTEND/TRUNCATE pair around the i8 ABI slot,
; the program doesn't compile at all (DAGBuilder type-check trips).

target triple = "mov-unknown-linux-gnu"

define i8 @add_i8_wrap(i8 %a, i8 %b) {
  %r = add i8 %a, %b
  ret i8 %r
}
