; Stage-2 fixture: identity at boundary value 0 (verifies the load isn't
; accidentally treating 0 as "no arg" anywhere).

target triple = "mov-unknown-linux-gnu"

define i32 @identity(i32 %x) {
  ret i32 %x
}
