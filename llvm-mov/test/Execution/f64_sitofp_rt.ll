; Stage 7h3 — sitofp + fptosi round-trip via __floatsidf + __fixdfsi.
; All i32 values fit exactly in f64 (53 bits mantissa), so the
; round-trip preserves the input exactly.
;
;   sitofp 42 → 42.0_f64
;   fptosi 42.0_f64 → 42

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i32 %i) {
  %d = sitofp i32 %i to double
  %r = fptosi double %d to i32
  ret i32 %r
}
