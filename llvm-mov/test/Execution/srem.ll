; Stage 7f2 — `srem i32` via the injected `__modsi3 (a, b)`. The
; helper computes
;   q = __udivsi3 (|a|, |b|)
;   r = |a| - q * |b|
;   return a < 0 ? -r : r
; The sign of the result matches the dividend (C / Rust convention),
; not the divisor.
;
; sremainder(-100, 7) = -2. Exit byte = 254.

target triple = "mov-unknown-linux-gnu"

define i32 @sremainder(i32 %a, i32 %b) {
  %r = srem i32 %a, %b
  ret i32 %r
}
