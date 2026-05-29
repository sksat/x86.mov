; Stage 7h3 — extract the f64 exponent byte after `sitofp i32 to
; double` to verify __floatsidf does the right rebias. For 42:
;   42 = 1.3125 × 2^5, biased exp = 5 + 1023 = 1028 = 0x404
;   (hi_word >> 20) & 0xFF = 0x404 & 0xFF = 0x04 = 4
;
; XOR-mixes lo and hi to keep both halves live (cdecl i64 return
; transit + post-call extraction tail-call hazard fix from 7h1 still
; applies in spirit — the EDX-save fix lets `lshr i64 + trunc` work
; reliably, but XOR-mixing matches the f64_extend* pattern and is
; explicit about using both halves).

target triple = "mov-unknown-linux-gnu"

define i32 @sitofp_exp(i32 %i) {
  %d = sitofp i32 %i to double
  %b = bitcast double %d to i64
  %lo = trunc i64 %b to i32
  %hi64 = lshr i64 %b, 32
  %hi = trunc i64 %hi64 to i32
  %mix = xor i32 %lo, %hi
  %t = lshr i32 %mix, 20
  %x = and i32 %t, 255
  ret i32 %x
}
