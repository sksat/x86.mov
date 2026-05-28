; Stage-2 fixture: identity(1) — discriminates against any constant-fold
; bug that would let MOV32rm collapse to MOV32ri with the wrong immediate.

target triple = "mov-unknown-linux-gnu"

define i32 @identity(i32 %x) {
  ret i32 %x
}
