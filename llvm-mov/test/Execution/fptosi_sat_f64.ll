; Stage 7h8 — `llvm.fptosi.sat.i32.f64` Custom-lowered to plain
; `fptosi` (via __fixdfsi). Round-trips a sitofp + saturating
; fptosi for `(i32) 42`.

target triple = "mov-unknown-linux-gnu"

declare i32 @llvm.fptosi.sat.i32.f64(double)

define i32 @sat_rt(i32 %i) {
  %d = sitofp i32 %i to double
  %r = call i32 @llvm.fptosi.sat.i32.f64(double %d)
  ret i32 %r
}
