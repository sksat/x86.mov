; Stage 7h3 — round-trip with a negative input. -5 → -5.0_f64 → -5.
; Exit code's low byte = 0xFB = 251.

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i32 %i) {
  %d = sitofp i32 %i to double
  %r = fptosi double %d to i32
  ret i32 %r
}
