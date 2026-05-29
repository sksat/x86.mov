; Stage 7h4 mov-only assert for `fsub double`. Same as f64_fadd —
; `__subdf3` tail-calls `__adddf3` after flipping b's sign bit, so
; the only non-mov mnemonic is the dispatcher jmp.

target triple = "mov-unknown-linux-gnu"

define double @fsub_passthrough(double %a, double %b) {
  %r = fsub double %a, %b
  ret double %r
}
