; Stage 7h6 — fdiv double round-trip. 42 / 7 = 6.

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i32 %i, i32 %j) {
  %a = sitofp i32 %i to double
  %b = sitofp i32 %j to double
  %r = fdiv double %a, %b
  %x = fptosi double %r to i32
  ret i32 %x
}
