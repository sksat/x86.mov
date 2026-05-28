; Stage 7f2 — `urem i32` via the injected `__umodsi3 (n, d)`.
; urem(100, 7) = 2. The injected helper computes
;   q = __udivsi3(n, d)
;   r = n - q * d
; (`q * d` lowers through the now-mov-only MUL32rr from stage 7f1.)

target triple = "mov-unknown-linux-gnu"

define i32 @uremainder(i32 %n, i32 %d) {
  %r = urem i32 %n, %d
  ret i32 %r
}
