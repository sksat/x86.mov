; Stage 7c4 PoC fixture — signed-less-than on two regs (CMP32rr + JL).
; The 7c4 pass routes both lhs and rhs through their own sar_sign_byte
; lookup (the rr-form branch of the signed pre-compute) before the SUB
; chain overwrites srcdst. Runner calls smin(50, 42) → 42.

target triple = "mov-unknown-linux-gnu"

define i32 @smin(i32 %a, i32 %b) {
  %c = icmp slt i32 %a, %b
  br i1 %c, label %a_lt_b, label %a_ge_b
a_lt_b:
  ret i32 %a
a_ge_b:
  ret i32 %b
}
