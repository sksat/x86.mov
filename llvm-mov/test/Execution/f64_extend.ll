; Stage 7h1 — fpext f32 → f64. Verifies the IEEE-754 field rebias:
; f32 exp 127 (= 1.0 unbiased) → f64 exp 1023 = 0x3FF. We extract
; bits 26..19 of the f64 high word (= exp byte + quiet bit), giving
; 0xFE (254) for a finite-normal result, 0xFE for +Inf, 0xFF for
; qNaN — same shape as the 7g4 f32 Inf/NaN extraction.
;
;   1.0_f32 = 0x3F800000 = 1065353216
;   1.0_f64 = 0x3FF0000000000000 → top 32 = 0x3FF00000
;   (top >> 19) & 0xFF = 0xFE = 254

target triple = "mov-unknown-linux-gnu"

; XOR'ing the low and high halves of the f64 bit pattern keeps both
; live, blocking SDAG from emitting a tail-call jump through
; `__extendsfdf2`. (A tail call here would discard the high word in
; edx; the function returns i32 in eax which is the low half.) For
; every fpext fixture we feed a finite-or-special f32 whose extended
; f64 has the low 32 bits all-zero, so XORing folds cleanly to "hi".
define i32 @ext_top9(float %f) {
  %d   = fpext float %f to double
  %b   = bitcast double %d to i64
  %lo  = trunc i64 %b to i32
  %hi64 = lshr i64 %b, 32
  %hi  = trunc i64 %hi64 to i32
  %mix = xor i32 %lo, %hi
  %t   = lshr i32 %mix, 19
  %x   = and i32 %t, 255
  ret i32 %x
}
