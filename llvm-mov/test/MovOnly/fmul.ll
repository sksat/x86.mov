; Stage 7g2 mov-only assert for `fmul`. SDAG soft-float lowers the
; FP op into `call __mulsf3`; the injected `__mulsf3` body (driver-
; level IR) is straight-line bit-arithmetic over i32 with no native
; FP ops anywhere. After the 7d3 CALL rewrite + 7c1 dispatcher,
; `.text` has only mov + dispatcher jmp — no `cmp`, no `call`, no
; `fmul`, no `fldsp`.

target triple = "mov-unknown-linux-gnu"

define float @fmul_passthrough(float %a, float %b) {
  %r = fmul float %a, %b
  ret float %r
}
