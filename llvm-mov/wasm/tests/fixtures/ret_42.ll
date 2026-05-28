; Stage-1 fixture: `ret i32 42`.
; Verifies a non-zero constant materialises into EAX correctly.

target triple = "mov-unknown-linux-gnu"

define i32 @main() {
  ret i32 42
}
