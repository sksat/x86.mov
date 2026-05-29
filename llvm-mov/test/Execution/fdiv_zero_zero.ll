; Stage 7g3 — codex-review P2 regression on divisor-zero ordering.
; Stage 7g4 upgraded the 7g3 best-effort scope: 0/0 is now
; correctly the IEEE quiet NaN (0x7FC00000), not signed Inf.
;
; This fixture keeps the original "exp byte == 255" check (which is
; true for both Inf and NaN), so 7g3's signed-Inf and 7g4's NaN both
; satisfy it. The new fixture `fdiv_inf_inf` distinguishes Inf vs
; NaN explicitly via the quiet bit (bit 22).
;
;   0.0 / 0.0 → qNaN → exp byte = 0xFF = 255 (was: +Inf in 7g3)

target triple = "mov-unknown-linux-gnu"

define i32 @fdiv_exp(float %a, float %b) {
  %q    = fdiv float %a, %b
  %bits = bitcast float %q to i32
  %expA = lshr i32 %bits, 23
  %exp  = and i32 %expA, 255
  ret i32 %exp
}
