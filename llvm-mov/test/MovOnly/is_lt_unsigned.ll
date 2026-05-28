; Stage 7c3 PoC fixture — `icmp ult` + `br` lowers to CMP + JB
; (unsigned-less-than) which the 7c3 pass rewrites mov-only via:
;   - byte SUB chain (__mov_sub8_{diff,borrow}_table) into srcdst
;   - OR-reduce of diff bytes for ZF (here unused: predicate B doesn't
;     need ZF)
;   - CF byte from the final stage's borrow lookup, converted to a
;     0x00/0xFF mask via __mov_select_mask_table
;   - per-byte mask-based select into next_pc
;
; Runner calls with x = 1 (`is_lt_unsigned(1)` returns 1 because
; 1 < 0xFFFFFFFF unsigned).

target triple = "mov-unknown-linux-gnu"

define i32 @is_lt_unsigned(i32 %x) {
  %c = icmp ult i32 %x, -1   ; %x < 0xFFFFFFFF unsigned
  br i1 %c, label %yes, label %no
yes:
  ret i32 0
no:
  ret i32 1
}
