; Stage-4c fixture: read-modify-write through a single alloca slot.
; Stops mem2reg from collapsing the alloca by using `volatile`-ish access
; via store-then-reload of the bumped value. rmw(41) → 42.

target triple = "mov-unknown-linux-gnu"

define i32 @rmw(i32 %x) {
  %p = alloca i32, align 4
  store i32 %x, ptr %p
  %v = load i32, ptr %p
  %v2 = add i32 %v, 1
  store i32 %v2, ptr %p
  %r = load i32, ptr %p
  ret i32 %r
}
