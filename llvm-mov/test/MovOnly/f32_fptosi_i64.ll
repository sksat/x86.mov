; Stage 7h10 mov-only assert for `fptosi float to i64`. SDAG soft-
; float lowers it to `call __fixsfdi`.

target triple = "mov-unknown-linux-gnu"

define i64 @fptosi_f32_i64_passthrough(float %f) {
  %r = fptosi float %f to i64
  ret i64 %r
}
