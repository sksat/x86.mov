; Stage-4c fixture: two independent alloca slots + add. alloca_two(20, 22)
; → 42. Exercises that PEI lays out two stack slots cleanly and
; eliminateFrameIndex picks consistent offsets for both.

target triple = "mov-unknown-linux-gnu"

define i32 @alloca_two(i32 %a, i32 %b) {
  %p1 = alloca i32, align 4
  %p2 = alloca i32, align 4
  store i32 %a, ptr %p1
  store i32 %b, ptr %p2
  %v1 = load i32, ptr %p1
  %v2 = load i32, ptr %p2
  %r = add i32 %v1, %v2
  ret i32 %r
}
