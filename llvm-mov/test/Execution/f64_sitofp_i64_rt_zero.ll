; Stage 7h9 — zero round-trip.

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i64 %v) {
  %d = sitofp i64 %v to double
  %r = fptosi double %d to i64
  %lo = trunc i64 %r to i32
  ret i32 %lo
}
