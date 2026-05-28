; Stage-3 fixture: two i32 args, single `add`. add(20, 22) → 42.
; Exercises ADD32rr with both args loaded from the stack.

target triple = "mov-unknown-linux-gnu"

define i32 @add(i32 %a, i32 %b) {
  %r = add i32 %a, %b
  ret i32 %r
}
