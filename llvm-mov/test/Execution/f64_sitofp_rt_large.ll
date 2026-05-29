; Stage 7h3 — round-trip with a large positive value. 16777215
; (= 2^24 - 1, all 24 low bits set) is the largest f32-representable
; integer; f64 can represent the whole i32 range losslessly, so this
; just probes the mid-range shift path of `__floatsidf`.
;
;   16777215 → 16777215.0 → 16777215
;   low byte = 0xFF = 255

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i32 %i) {
  %d = sitofp i32 %i to double
  %r = fptosi double %d to i32
  ret i32 %r
}
