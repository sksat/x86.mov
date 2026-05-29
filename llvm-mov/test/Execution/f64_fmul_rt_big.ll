; Stage 7h5 — larger multiplication. 1000 × 1000 = 1000000. Low
; byte = 0x40 = 64.

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i32 %i, i32 %j) {
  %a = sitofp i32 %i to double
  %b = sitofp i32 %j to double
  %r = fmul double %a, %b
  %d = fptosi double %r to i32
  %x = and i32 %d, 255
  ret i32 %x
}
