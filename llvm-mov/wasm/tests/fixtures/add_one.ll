; Stage-3 fixture: one i32 arg, single `add` against an immediate, return.
; Runner calls add_one(41), expects exit 42 — exercises ADD32ri and the
; 2-address tied-operand convention.

target triple = "mov-unknown-linux-gnu"

define i32 @add_one(i32 %x) {
  %r = add i32 %x, 1
  ret i32 %r
}
