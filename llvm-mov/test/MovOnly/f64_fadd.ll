; Stage 7h4 mov-only assert for `fadd double`. SDAG soft-float
; lowers it to `call __adddf3`; the injected helper body uses i32-
; pair clamped-arm splits (same technique as 7h3 conversions) for
; the variable-amount mantissa shifts. After 7d3 + 7c1, `.text`
; has only mov + dispatcher jmp.

target triple = "mov-unknown-linux-gnu"

define double @fadd_passthrough(double %a, double %b) {
  %r = fadd double %a, %b
  ret double %r
}
