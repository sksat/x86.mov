; Stage 7g2 — sitofp + fmul + fptosi round-trip. Exercises the three
; helpers together for a small-int range where the multiply is
; bit-exact.
;
;   sitofp 6  → 6.0
;   6.0 * 7.0 → 42.0
;   fptosi    → 42

target triple = "mov-unknown-linux-gnu"

define i32 @round_trip(i32 %i, i32 %j) {
  %fi = sitofp i32 %i to float
  %fj = sitofp i32 %j to float
  %p  = fmul float %fi, %fj
  %r  = fptosi float %p to i32
  ret i32 %r
}
