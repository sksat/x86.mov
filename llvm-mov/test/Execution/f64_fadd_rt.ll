; Stage 7h4 — fadd double round-trip via sitofp + fadd + fptosi.
; Tests __floatsidf + __adddf3 + __fixdfsi together. Pure-integer
; round-trip is exact for any i32 fitting in 53 bits of f64
; mantissa (= all i32).
;
;   sitofp(3) + sitofp(4) → 7.0 → 7

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i32 %i, i32 %j) {
  %a = sitofp i32 %i to double
  %b = sitofp i32 %j to double
  %r = fadd double %a, %b
  %x = fptosi double %r to i32
  ret i32 %x
}
