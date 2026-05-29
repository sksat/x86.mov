; Stage 7h10 mov-only assert for `sitofp i64 to float`. SDAG soft-
; float lowers it to `call __floatdisf`. After 7d3 + 7c1, .text is
; only mov + dispatcher jmp.

target triple = "mov-unknown-linux-gnu"

define float @sitofp_i64_passthrough(i64 %v) {
  %f = sitofp i64 %v to float
  ret float %f
}
