; Stage 7h11 mov-only assert for `llvm.trunc.f32` (math trunc).

target triple = "mov-unknown-linux-gnu"

declare float @llvm.trunc.f32(float)

define float @mtrunc_passthrough(float %f) {
  %r = call float @llvm.trunc.f32(float %f)
  ret float %r
}
