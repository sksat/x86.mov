; Stage 7h4 — fsub yielding a negative result. 3 - 10 = -7.
; low byte = 0xF9 = 249.

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i32 %i, i32 %j) {
  %a = sitofp i32 %i to double
  %b = sitofp i32 %j to double
  %r = fsub double %a, %b
  %x = fptosi double %r to i32
  ret i32 %x
}
