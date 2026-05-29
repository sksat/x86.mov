; Stage 7g1 — `fptosi float → i32` via `__fixsfsi`. SDAG legalize
; emits `call __fixsfsi(float) → i32`, with truncation toward zero.
;
; 42.7 → 42 (truncate toward zero). 42.7 in IEEE-754 = 0x422acccd
; (= 1110101197).

target triple = "mov-unknown-linux-gnu"

define i32 @to_int(float %f) {
  %i = fptosi float %f to i32
  ret i32 %i
}
