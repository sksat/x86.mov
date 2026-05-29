; Stage 7h4 — fsub double round-trip. 10 - 3 = 7. fsub is
; implemented as `__subdf3(a, b) = __adddf3(a, -b)` (sign-flip of
; b's i64-hi bit 31).

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i32 %i, i32 %j) {
  %a = sitofp i32 %i to double
  %b = sitofp i32 %j to double
  %r = fsub double %a, %b
  %x = fptosi double %r to i32
  ret i32 %x
}
