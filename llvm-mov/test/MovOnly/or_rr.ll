; Stage 7b1 PoC fixture — bitwise OR, register-register form.
;
; Two-arg `or` exercises the rr leg of the bitwise legalization path:
; the RHS register is spilled to rhs_buf once, and each byte stage
; loads its b_byte from `[rhs_buf + i]` before looking up the result
; in __mov_or8_table.

target triple = "mov-unknown-linux-gnu"

define i32 @or_rr(i32 %a, i32 %b) {
  %r = or i32 %a, %b
  ret i32 %r
}
