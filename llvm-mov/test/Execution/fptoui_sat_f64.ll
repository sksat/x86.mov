; Stage 7h8 — `llvm.fptoui.sat.i32.f64` Custom-lowered.

target triple = "mov-unknown-linux-gnu"

declare i32 @llvm.fptoui.sat.i32.f64(double)

define i32 @sat_rt(i32 %i) {
  %d = sitofp i32 %i to double
  %r = call i32 @llvm.fptoui.sat.i32.f64(double %d)
  %x = and i32 %r, 255
  ret i32 %x
}
