; Stage 7f mov-only assert for `mul`. The new MUL32rr pseudo +
; byte-table lowering keeps `.text` mov-only modulo the dispatcher
; `jmp`. Pre-stage-7f the Expand path emitted `call __mulsi3`, which
; both leaked `call` to .text AND required a user-crate stub to
; resolve at link time.

target triple = "mov-unknown-linux-gnu"

define i32 @multiply(i32 %a, i32 %b) {
  %r = mul i32 %a, %b
  ret i32 %r
}
