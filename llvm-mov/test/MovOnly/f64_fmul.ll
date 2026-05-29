; Stage 7h5 mov-only assert for `fmul double`. SDAG soft-float
; lowers it to `call __muldf3`; the injected body computes the
; 53×53 → 106-bit mantissa multiply via four 32×32 → 64-bit
; sub-multiplies (each split internally into four 16×16 muls so
; the existing stage-7f1 byte-table `mul i32` covers everything).
; After 7d3 + 7c1, `.text` is only mov + dispatcher jmp.

target triple = "mov-unknown-linux-gnu"

define double @fmul_passthrough(double %a, double %b) {
  %r = fmul double %a, %b
  ret double %r
}
