; Stage 7h11 mov-only assert for `llvm.ceil.f32`.

target triple = "mov-unknown-linux-gnu"

declare float @llvm.ceil.f32(float)

define float @ceil_passthrough(float %f) {
  %r = call float @llvm.ceil.f32(float %f)
  ret float %r
}
