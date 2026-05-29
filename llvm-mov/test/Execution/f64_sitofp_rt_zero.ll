; Stage 7h3 — zero round-trip. 0 → +0.0_f64 → 0. Catches a missing
; zero short-circuit in either helper.

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i32 %i) {
  %d = sitofp i32 %i to double
  %r = fptosi double %d to i32
  ret i32 %r
}
