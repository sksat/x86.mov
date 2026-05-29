; Stage 7g1 — `fcmp` via SDAG soft-float → `call __ltsf2(a, b)`. The
; SDAG legalizer turns `fcmp olt` into `icmp slt (__ltsf2(a, b)), 0`.
;
; fcmp olt 1.5, 2.5 → true → return 42; fcmp olt 2.5, 1.5 → false →
; return 7. Caller runs with a < b for exit 42.

target triple = "mov-unknown-linux-gnu"

define i32 @cmp(float %a, float %b) {
  %lt = fcmp olt float %a, %b
  %r  = select i1 %lt, i32 42, i32 7
  ret i32 %r
}
