; Stage 7h5 — sign XOR: -3 × 4 = -12 → low byte = 0xF4 = 244.

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i32 %i, i32 %j) {
  %a = sitofp i32 %i to double
  %b = sitofp i32 %j to double
  %r = fmul double %a, %b
  %x = fptosi double %r to i32
  ret i32 %x
}
