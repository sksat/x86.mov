; Stage-6a fixture: call with two i32 args. caller(20, 22) → add(20, 22) → 42.
; Exercises arg ordering across the cdecl stack (right-to-left push, but
; SelectionDAG emits stores by ascending offset — verifies LowerCall's
; use of VA.getLocMemOffset()).

target triple = "mov-unknown-linux-gnu"

define internal i32 @add(i32 %a, i32 %b) {
  %r = add i32 %a, %b
  ret i32 %r
}

define i32 @caller(i32 %x, i32 %y) {
  %r = call i32 @add(i32 %x, i32 %y)
  ret i32 %r
}
