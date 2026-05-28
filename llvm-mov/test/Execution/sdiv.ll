; Stage 7f2 — `sdiv i32` via the injected `__divsi3 (a, b)`. The
; helper computes
;   sign = (a < 0) ^ (b < 0)
;   q    = __udivsi3 (|a|, |b|)
;   return sign ? -q : q
; using only mov-only-legal arithmetic (no `idiv`).
;
; sdivide(-100, 7) = -14. The runner returns the result as a byte exit
; code, so -14 wraps to (0xFFFFFFF2 & 0xFF) = 0xF2 = 242.

target triple = "mov-unknown-linux-gnu"

define i32 @sdivide(i32 %a, i32 %b) {
  %q = sdiv i32 %a, %b
  ret i32 %q
}
