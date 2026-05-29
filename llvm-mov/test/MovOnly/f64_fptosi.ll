; Stage 7h3 mov-only assert for `fptosi double to i32`. Same as
; sitofp but in the other direction (routes through __fixdfsi).

target triple = "mov-unknown-linux-gnu"

define i32 @fptosi_passthrough(double %d) {
  %i = fptosi double %d to i32
  ret i32 %i
}
