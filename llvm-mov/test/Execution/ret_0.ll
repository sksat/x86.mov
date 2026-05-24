; Stage-0 fixture: smallest possible program.
; Expected runtime behaviour: linked ELF exits with status 0.

target triple = "mov-unknown-linux-gnu"

define i32 @main() {
  ret i32 0
}
