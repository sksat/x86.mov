; Stage 7b3 PoC fixture — variable-amount left shift, mov-only.
;
; SHL by a runtime amount goes through the 5-stage power-of-2
; unrolling: stages compute shift-by-1, -2, -4, -8, -16 candidates
; into shifted_buf, with a mask-based select picking each candidate
; conditional on the matching bit of the amount.

target triple = "mov-unknown-linux-gnu"

define i32 @shl_rCL(i32 %x, i32 %n) {
  %r = shl i32 %x, %n
  ret i32 %r
}
