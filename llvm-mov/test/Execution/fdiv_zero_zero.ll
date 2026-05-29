; Stage 7g3 — codex-review P2 regression. 0.0 / 0.0 must surface as
; signed Inf in our best-effort scope (real IEEE would emit a quiet
; NaN; out-of-scope alongside `__addsf3` etc.). The original select
; order applied `AIsZero` after `BIsZero`, so 0/0 silently returned
; signed zero instead of Inf — fixed by swapping the gate order so
; divisor-zero wins.
;
;   0.0 / 0.0 → +Inf → exp byte = 0xFF = 255

target triple = "mov-unknown-linux-gnu"

define i32 @fdiv_exp(float %a, float %b) {
  %q    = fdiv float %a, %b
  %bits = bitcast float %q to i32
  %expA = lshr i32 %bits, 23
  %exp  = and i32 %expA, 255
  ret i32 %exp
}
