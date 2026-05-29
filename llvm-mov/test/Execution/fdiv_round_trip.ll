; Stage 7g3 — sitofp + fdiv + fptosi round-trip. Exercises the three
; helpers together for a small-int range where the divide is
; bit-exact.
;
;   sitofp 10 → 10.0
;   sitofp 5  → 5.0
;   10.0 / 5.0 = 2.0
;   fptosi    → 2

target triple = "mov-unknown-linux-gnu"

define i32 @round_trip(i32 %i, i32 %j) {
  %fi = sitofp i32 %i to float
  %fj = sitofp i32 %j to float
  %q  = fdiv float %fi, %fj
  %r  = fptosi float %q to i32
  ret i32 %r
}
