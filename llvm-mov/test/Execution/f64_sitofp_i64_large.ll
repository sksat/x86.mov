; Stage 7h9 — 1000000 → 1000000.0 → 1000000. Low byte = 64.

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i64 %v) {
  %d = sitofp i64 %v to double
  %r = fptosi double %d to i64
  %lo = trunc i64 %r to i32
  %x = and i32 %lo, 255
  ret i32 %x
}
