; Stage 7h9 mov-only assert for `sitofp i64 to double`. SDAG soft-
; float lowers it to `call __floatdidf`. After 7d3 + 7c1, .text is
; only mov + dispatcher jmp.

target triple = "mov-unknown-linux-gnu"

define double @sitofp_i64_passthrough(i64 %v) {
  %d = sitofp i64 %v to double
  ret double %d
}
