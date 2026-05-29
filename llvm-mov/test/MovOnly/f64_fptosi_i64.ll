; Stage 7h9 mov-only assert for `fptosi double to i64`. SDAG soft-
; float lowers it to `call __fixdfdi`.

target triple = "mov-unknown-linux-gnu"

define i64 @fptosi_i64_passthrough(double %d) {
  %r = fptosi double %d to i64
  ret i64 %r
}
