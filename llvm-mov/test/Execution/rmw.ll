; Stage-4c fixture: alloca-backed local slot read-modify-write WITHOUT an
; i32 formal argument. The no-arg shape is deliberate — Stack Slot
; Coloring would otherwise merge the alloca slot with the cdecl arg
; slot (legal under cdecl because the caller doesn't trust arg slots
; post-call), and the emitted asm would write to `[ebp + 8]` instead of
; the intended `[ebp - 4]`, defeating the test (see codex's stage-4c
; review of d55ccfe).
;
; With no args, SSC has no other slot to merge with: the alloca survives
; to PEI, gets laid out at `[ebp - 4]`, and our eliminateFrameIndex
; resolves the FrameIndex to that address. The load right before `ret`
; pulls the just-stored value back, so the optimiser can't constant-fold
; it away.

target triple = "mov-unknown-linux-gnu"

define i32 @rmw() {
  %p = alloca i32, align 4
  store i32 41, ptr %p
  %v = load i32, ptr %p
  %v2 = add i32 %v, 1
  store i32 %v2, ptr %p
  %r = load i32, ptr %p
  ret i32 %r
}
