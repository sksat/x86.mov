; Stage-3 fixture: 2-address binop chain. Per codex's stage-3 design
; review: simple one-op fixtures don't actually exercise the
; `Constraints = "$src1 = $dst"` tie — RA might happen to pick the same
; physical reg for both. A chain where the result of one op feeds the
; next AND the original args are still live forces copies, and only
; passes if the tie holds.
;
; t1 = a + b ; t2 = t1 + a ; t3 = t2 + b → 2a + 2b
; With a=10, b=11 → 2·10 + 2·11 = 42.

target triple = "mov-unknown-linux-gnu"

define i32 @add_chain(i32 %a, i32 %b) {
  %t1 = add i32 %a, %b
  %t2 = add i32 %t1, %a
  %t3 = add i32 %t2, %b
  ret i32 %t3
}
