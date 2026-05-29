; Stage 7h9 — negative i64 round-trip. -5 → -5.0 → -5. Low byte = 251.

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i64 %v) {
  %d = sitofp i64 %v to double
  %r = fptosi double %d to i64
  %lo = trunc i64 %r to i32
  ret i32 %lo
}
