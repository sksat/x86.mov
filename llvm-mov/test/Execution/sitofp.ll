; Stage 7g1 — `sitofp i32 → float` via `__floatsisf`. SDAG legalize
; emits `call __floatsisf(i32) → float`.
;
; (i32)123 → 123.0 = 0x42F60000 → exponent byte = 0x85 = 133.

target triple = "mov-unknown-linux-gnu"

define i32 @to_float_exp(i32 %i) {
  %f    = sitofp i32 %i to float
  %bits = bitcast float %f to i32
  %s    = lshr i32 %bits, 23
  %r    = and i32 %s, 255
  ret i32 %r
}
