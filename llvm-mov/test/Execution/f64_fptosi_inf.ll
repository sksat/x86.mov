; Stage 7h3 codex-review P1 regression. For inputs whose exponent
; is outside the in-range window (here +Inf, exp = 0x7FF), ShiftR
; in `__fixdfsi` would wrap and emit poison-arm bit-blended shifts
; without explicit ClampTo31. The fix clamps every shift count to
; ≤ 31 so each arm of the bit-blend is well-defined; the exp-based
; saturation gate then routes the result to INT_MAX (low byte
; 0xFF = 255).
;
;   +Inf_f64 = 0x7FF0000000000000  →  lo = 0, hi = 0x7FF00000
;   fptosi → INT_MAX → low byte = 0xFF = 255

target triple = "mov-unknown-linux-gnu"

define i32 @fptosi_test(i64 %bits) {
  %d = bitcast i64 %bits to double
  %i = fptosi double %d to i32
  ret i32 %i
}
