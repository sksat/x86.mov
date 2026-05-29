; Stage 7g1 regression for codex-review P1 in `__floatsisf`. For an
; input whose MSB is well below bit 23 — e.g. 123 = 0b1111011, hi = 6
; — the lossy-right branch's `Hi - 23` wraps to 0xFFFFFFEF (≫ 31).
; The driver's SELECT → bit-blend rewrite materialises both arms, so
; an unclamped right-shift becomes poison and can corrupt the bit-
; blend output. The clamp keeps both shifts in [0, 23] regardless of
; which arm the final select chooses.
;
; (i32) 123 → 123.0. Exponent byte = 0x85 = 133, mantissa = 0xEC0000,
; so the returned float bits are 0x42F60000. We check the low byte of
; the result (0x00) to also verify the lossless-left-shift kept its
; bottom bits clean — a poisoned lossy right path would leak into the
; bit-blend output and surface here.

target triple = "mov-unknown-linux-gnu"

define i32 @to_float_low(i32 %i) {
  %f    = sitofp i32 %i to float
  %bits = bitcast float %f to i32
  %lo   = and i32 %bits, 255
  ret i32 %lo
}
