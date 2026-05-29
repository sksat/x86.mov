; Stage 7h11 mov-only assert for `llvm.floor.f32`.

target triple = "mov-unknown-linux-gnu"

declare float @llvm.floor.f32(float)

define float @floor_passthrough(float %f) {
  %r = call float @llvm.floor.f32(float %f)
  ret float %r
}
