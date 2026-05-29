; Stage 7g1 mov-only assert for `fadd`. SDAG soft-float lowers the
; FP op into `call __addsf3`; the injected `__addsf3` body (driver-
; level IR) is straight-line bit-arithmetic over i32 with no native
; FP ops anywhere. After the 7d3 CALL rewrite + 7c1 dispatcher,
; `.text` has only mov + dispatcher jmp — no `cmp`, no `call`, no
; `fadd`, no `fldsp`.

target triple = "mov-unknown-linux-gnu"

define float @fadd_passthrough(float %a, float %b) {
  %r = fadd float %a, %b
  ret float %r
}
