; Stage 7g3 mov-only assert for `fdiv`. SDAG soft-float lowers the
; FP op into `call __divsf3`; the injected `__divsf3` body (driver-
; level IR) is a 23-iter long-division loop over i32 with no native
; FP ops anywhere. After the 7d3 CALL rewrite + 7c1 dispatcher,
; `.text` has only mov + dispatcher jmp — no `cmp`, no `call`, no
; `fdiv`, no `fldsp`.

target triple = "mov-unknown-linux-gnu"

define float @fdiv_passthrough(float %a, float %b) {
  %r = fdiv float %a, %b
  ret float %r
}
