; Stage 7f2 mov-only assert for the worst-case signed-remainder shape.
; `srem` selects to a `call __modsi3` whose body delegates to
; `__udivsi3` (long-division loop), `MUL32rr` (already mov-only via
; stage 7f1), and branchless abs / sign-fixup. None of those leak
; non-mov mnemonics into `.text`.

target triple = "mov-unknown-linux-gnu"

define i32 @sremainder(i32 %a, i32 %b) {
  %r = srem i32 %a, %b
  ret i32 %r
}
