; Stage 7g1 mov-only assert for `sitofp i32 → float`.

target triple = "mov-unknown-linux-gnu"

define float @sitofp_passthrough(i32 %i) {
  %f = sitofp i32 %i to float
  ret float %f
}
