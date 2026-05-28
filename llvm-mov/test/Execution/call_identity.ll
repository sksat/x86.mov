; Stage-6a fixture: smallest user-defined function call. The runner
; invokes caller(42); caller forwards to callee(42); callee returns 42.
; If LowerCall, CALL32d emission, or the CALLSEQ_*-pseudo elimination
; goes wrong, this exits with something other than 42.

target triple = "mov-unknown-linux-gnu"

define internal i32 @callee(i32 %a) {
  ret i32 %a
}

define i32 @caller(i32 %x) {
  %r = call i32 @callee(i32 %x)
  ret i32 %r
}
