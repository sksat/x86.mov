; Stage-5c fixture: icmp eq + br. is_42(42) → 1, is_42(7) → 0.
; Exercises CMP32ri + JNE + JMP and analyzeBranch's two-terminator path.
; This fixture covers the 42 case; is_not_42.ll covers the false branch.

target triple = "mov-unknown-linux-gnu"

define i32 @is_42(i32 %x) {
  %c = icmp eq i32 %x, 42
  br i1 %c, label %yes, label %no
yes:
  ret i32 1
no:
  ret i32 0
}
