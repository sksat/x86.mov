; Stage 7g1 — `fadd float` via SDAG Expand → `call __addsf3`, whose body
; is injected by the llvm-mov-llc driver as IR.
;
; fadd 1.5 + 2.5 = 4.0. The exponent byte of 4.0 (IEEE-754 single) is
; 0x81 (= 129). We extract it as the test's exit code so even a
; mantissa-bit accuracy issue stays visible.
;
;   1.5 = 0x3FC00000 = 1069547520
;   2.5 = 0x40200000 = 1075838976
;   4.0 = 0x40800000  →  (bits >> 23) & 0xFF = 0x81 = 129

target triple = "mov-unknown-linux-gnu"

define i32 @fadd_exp(float %a, float %b) {
  %sum  = fadd float %a, %b
  %bits = bitcast float %sum to i32
  %expA = lshr i32 %bits, 23
  %exp  = and i32 %expA, 255
  ret i32 %exp
}
