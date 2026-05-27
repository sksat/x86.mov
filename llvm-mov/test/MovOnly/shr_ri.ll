; Stage 7b2 PoC fixture — logical (unsigned) right shift, mov-only.
;
; `lshr i32 %x, 3` covers the SHR32ri path. Byte chain runs low-to-
; high; OOR high-side sources contribute 0 (the SHR difference from
; SAR).

target triple = "mov-unknown-linux-gnu"

define i32 @shr_ri(i32 %x) {
  %r = lshr i32 %x, 3
  ret i32 %r
}
