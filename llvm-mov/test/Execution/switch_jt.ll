; Issue #11 — dep coverage. A dense `switch` is what LLVM lowers to a
; jump table (`br_jt` + JumpTable), the exact node that aborts ISel on
; the `base64` / `qoi` deps (both inside their error enums'
; `core::fmt::Display::fmt`). With jump tables disabled the switch must
; instead lower to the BR_CC compare chain the backend already handles
; end-to-end, so this fixture exercising five dense arms should run
; mov-only.
;
; switch_jt(3) walks to case 3 → returns 30.

target triple = "mov-unknown-linux-gnu"

define i32 @switch_jt(i32 %x) {
entry:
  switch i32 %x, label %default [
    i32 0, label %c0
    i32 1, label %c1
    i32 2, label %c2
    i32 3, label %c3
    i32 4, label %c4
  ]
c0:
  ret i32 10
c1:
  ret i32 11
c2:
  ret i32 20
c3:
  ret i32 30
c4:
  ret i32 40
default:
  ret i32 99
}
