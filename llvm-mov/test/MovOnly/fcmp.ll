; Stage 7g1 mov-only assert for `fcmp`. The injected `__ltsf2` body
; is straight-line bit-arithmetic with the total-order key trick;
; SDAG's libcall → icmp lowering goes through the existing CMP+Jcc
; mov-only legalize.

target triple = "mov-unknown-linux-gnu"

define i32 @fcmp_lt_passthrough(float %a, float %b) {
  %c = fcmp olt float %a, %b
  %r = select i1 %c, i32 1, i32 0
  ret i32 %r
}
