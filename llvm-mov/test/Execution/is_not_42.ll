; Stage-5c fixture: same function as is_42 but called with a value that
; falls through to the false branch. Together with is_42 this covers
; both arms of the icmp/br.

target triple = "mov-unknown-linux-gnu"

define i32 @is_42_or_zero(i32 %x) {
  %c = icmp eq i32 %x, 42
  br i1 %c, label %yes, label %no
yes:
  ret i32 1
no:
  ret i32 0
}
