; Stage-2 fixture: a function that takes one i32 argument and returns it
; unchanged. The runner calls identity(42) via cdecl from _start; we
; expect the linked ELF to exit 42 (i.e. the argument has to make it from
; [esp+4] back into EAX).

target triple = "mov-unknown-linux-gnu"

define i32 @identity(i32 %x) {
  ret i32 %x
}
