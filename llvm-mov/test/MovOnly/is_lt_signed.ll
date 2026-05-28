; Stage 7c4 PoC fixture — `icmp slt` + `br` lowers to CMP + JL
; (signed-less-than) which the 7c4 pass rewrites mov-only via:
;   - shared SUB byte chain (__mov_sub8_{diff,borrow}_table) into srcdst
;     (Phase 1' — same as 7c3 unsigned)
;   - shared OR-reduce of diff bytes for ZF (Phase 2')
;   - signed-only pre-compute: a_sign = sar_sign[lhs[3]], X = a_sign XOR
;     b_sign (b_sign is a compile-time constant here)
;   - signed flag math: SF_mask = sar_sign[diff[3]], Y = a_sign XOR diff_sign,
;     OF_mask = X AND Y, t = SF XOR OF, mask = t (for L)
;   - per-byte mask-based select into next_pc
;
; Runner calls with x = 1 (`is_lt_signed(1)` returns 1 because 1 < 5 signed).

target triple = "mov-unknown-linux-gnu"

define i32 @is_lt_signed(i32 %x) {
  %c = icmp slt i32 %x, 5
  br i1 %c, label %yes, label %no
yes:
  ret i32 1
no:
  ret i32 0
}
