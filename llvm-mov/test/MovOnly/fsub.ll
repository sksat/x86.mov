; Stage 7g1 mov-only assert for `fsub`. The injected `__subsf3`
; flips b's sign bit and tail-calls `__addsf3`; both are straight-line
; bit-arithmetic. Only mov + dispatcher jmp should survive.

target triple = "mov-unknown-linux-gnu"

define float @fsub_passthrough(float %a, float %b) {
  %r = fsub float %a, %b
  ret float %r
}
