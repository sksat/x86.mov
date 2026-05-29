; Stage 7h6 mov-only assert for `fdiv double`. SDAG soft-float
; lowers it to `call __divdf3`; the injected body runs a 52-iter
; mantissa long-division loop (with PHIs, like stage-7g3 `__divsf3`)
; over i64 values. After 7d3 + 7c1, `.text` is only mov + dispatcher
; jmp.

target triple = "mov-unknown-linux-gnu"

define double @fdiv_passthrough(double %a, double %b) {
  %r = fdiv double %a, %b
  ret double %r
}
