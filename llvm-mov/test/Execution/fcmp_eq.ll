; Stage 7g1 — `fcmp oeq` via `__eqsf2`. SDAG legalize converts the
; libcall result to `icmp eq i32 (__eqsf2(a, b)), 0`. We test both
; the equal and not-equal paths via the same callargs choice.
;
; Caller: 2.5 vs 2.5 → equal → return 99; else 0.

target triple = "mov-unknown-linux-gnu"

define i32 @cmp(float %a, float %b) {
  %eq = fcmp oeq float %a, %b
  %r  = select i1 %eq, i32 99, i32 0
  ret i32 %r
}
