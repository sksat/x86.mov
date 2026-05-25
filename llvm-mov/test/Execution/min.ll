; Stage-5c fixture: signed minimum. min(50, 42) → 42; tests the signed-less-than
; predicate (JL).

target triple = "mov-unknown-linux-gnu"

define i32 @smin(i32 %a, i32 %b) {
  %c = icmp slt i32 %a, %b
  br i1 %c, label %a_lt_b, label %a_ge_b
a_lt_b:
  ret i32 %a
a_ge_b:
  ret i32 %b
}
