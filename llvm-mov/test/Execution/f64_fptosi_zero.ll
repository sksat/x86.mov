; Stage 7h3 — fptosi on +0.0_f64 = 0.

target triple = "mov-unknown-linux-gnu"

define i32 @fptosi_test(i64 %bits) {
  %d = bitcast i64 %bits to double
  %i = fptosi double %d to i32
  ret i32 %i
}
