; Stage 7g1 regression for codex-review P2 in `__fixunssfsi`. A large
; negative input ( |f| ≥ 2^32 ) must return 0, not UINT_MAX. The
; original implementation applied the negative-clamp first and the
; overflow-saturation second, so this input hit both gates and ended
; up at UINT_MAX. The fix conditions the overflow saturation on the
; positive sign and applies the negative clamp last.
;
; -1.0 with fptoui → 0 (negative input). Low byte = 0.
;
; -1.0 = 0xBF800000 = 3212836864 — a small negative that already had
; the right behaviour. The harder case is fed via the bitcast trick
; in a separate fixture; here we exercise the simple negative input
; that previously could be perturbed by the bit-blend evaluation
; order.

target triple = "mov-unknown-linux-gnu"

define i32 @to_uint_low(float %f) {
  %u  = fptoui float %f to i32
  %lo = and i32 %u, 255
  ret i32 %lo
}
