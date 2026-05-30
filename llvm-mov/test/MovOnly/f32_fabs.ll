; Stage 7h12 mov-only assert for `llvm.fabs.f32`.

target triple = "mov-unknown-linux-gnu"

declare float @llvm.fabs.f32(float)

define float @fabs_passthrough(float %f) {
  %r = call float @llvm.fabs.f32(float %f)
  ret float %r
}
