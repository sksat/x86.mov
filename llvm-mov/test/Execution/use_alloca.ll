; Stage-4c fixture: a single alloca + store + load round-trip.
; Confirms the MOV32mr DAG pattern (added in 4b for spill, but also valid
; for `store` selection) matches a static-alloca FrameIndex, and that
; eliminateFrameIndex's EBP-base lowering rewrites both the store and the
; load to consistent `[ebp - N]` displacements.

target triple = "mov-unknown-linux-gnu"

define i32 @use_alloca(i32 %x) {
  %p = alloca i32, align 4
  store i32 %x, ptr %p
  %r = load i32, ptr %p
  ret i32 %r
}
