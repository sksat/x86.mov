; Stage-1 fixture: upper boundary of the exit-code byte.
; Linux `exit` only preserves the low 8 bits of the status; 255 is the
; largest value where (retval & 0xff) == retval, so it doubles as a
; sanity check that we're not accidentally sign-extending.

target triple = "mov-unknown-linux-gnu"

define i32 @main() {
  ret i32 255
}
