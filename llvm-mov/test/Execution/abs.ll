; Stage-5c fixture: absolute value. abs(-42) → 42.
; icmp slt %x, 0 → JGE/JL. Tests the slt-vs-0 idiom + sub-from-zero
; for the negative arm.

target triple = "mov-unknown-linux-gnu"

define i32 @abs(i32 %x) {
  %neg = icmp slt i32 %x, 0
  br i1 %neg, label %is_neg, label %is_nonneg
is_neg:
  %n = sub i32 0, %x
  ret i32 %n
is_nonneg:
  ret i32 %x
}
