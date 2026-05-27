; Stage 7b3 PoC fixture — variable-amount arithmetic right shift,
; mov-only. Exercises the SAR rCL path: sign byte computed once from
; orig[3] at the prologue and substituted for OOR high-side bytes in
; each of the 5 shift-by-2^k stages.

target triple = "mov-unknown-linux-gnu"

define i32 @sar_rCL(i32 %x, i32 %n) {
  %r = ashr i32 %x, %n
  ret i32 %r
}
