; Stage 7h8 — `llvm.fptosi.sat.i32.f32` Custom-lowered to plain
; `fptosi` (which goes via `__fixsfsi`, already saturating).
;
;   42.0_f32 = 0x42280000 = 1109917696
;   saturating fptosi → 42

target triple = "mov-unknown-linux-gnu"

declare i32 @llvm.fptosi.sat.i32.f32(float)

define i32 @fptosi_sat(float %f) {
  %r = call i32 @llvm.fptosi.sat.i32.f32(float %f)
  ret i32 %r
}
