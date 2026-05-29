; Stage 7g1 mov-only assert for `fptosi float → i32`.

target triple = "mov-unknown-linux-gnu"

define i32 @fptosi_passthrough(float %f) {
  %i = fptosi float %f to i32
  ret i32 %i
}
