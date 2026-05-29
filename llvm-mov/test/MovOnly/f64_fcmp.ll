; Stage 7h2 mov-only assert for `fcmp double`. SDAG soft-float
; lowers each fcmp predicate to a call into `__{eq,ne,lt,le,gt,ge,
; unord}df2`; the injected helper bodies are straight-line bit
; arithmetic over i32 pairs (no i64 select). After the 7d3 CALL
; rewrite + 7c1 dispatcher, `.text` has only mov + dispatcher jmp.

target triple = "mov-unknown-linux-gnu"

define i1 @fcmp_passthrough(double %a, double %b) {
  %r = fcmp olt double %a, %b
  ret i1 %r
}
