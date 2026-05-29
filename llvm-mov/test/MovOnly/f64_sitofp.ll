; Stage 7h3 mov-only assert for `sitofp i32 to double`. SDAG soft-
; float lowers it to `call __floatsidf`; the injected helper body
; is straight-line bit arithmetic with i32 and constant-amount
; i64 shifts. After 7d3 + 7c1, `.text` has only mov + dispatcher
; jmp.

target triple = "mov-unknown-linux-gnu"

define double @sitofp_passthrough(i32 %i) {
  %d = sitofp i32 %i to double
  ret double %d
}
