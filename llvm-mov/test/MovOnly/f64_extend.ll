; Stage 7h1 mov-only assert for `fpext f32 to f64`. SDAG soft-float
; lowers fpext to `call __extendsfdf2`; the injected helper body
; is straight-line bit manipulation over i32/i64 with no FP ops.
; After the 7d3 CALL rewrite + 7c1 dispatcher, `.text` has only
; mov + dispatcher jmp.

target triple = "mov-unknown-linux-gnu"

define double @ext_passthrough(float %f) {
  %d = fpext float %f to double
  ret double %d
}
