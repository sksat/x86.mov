; Stage 7h12 mov-only assert for `llvm.copysign.f32`.

target triple = "mov-unknown-linux-gnu"

declare float @llvm.copysign.f32(float, float)

define float @copysign_passthrough(float %x, float %y) {
  %r = call float @llvm.copysign.f32(float %x, float %y)
  ret float %r
}
