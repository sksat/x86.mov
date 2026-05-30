; Stage 7h11 mov-only assert for `llvm.round.f32`.

target triple = "mov-unknown-linux-gnu"

declare float @llvm.round.f32(float)

define float @round_passthrough(float %f) {
  %r = call float @llvm.round.f32(float %f)
  ret float %r
}
