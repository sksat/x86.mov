; Stage 7c2 PoC fixture — `cmp + jcc(E/NE)` legalised to mov-only.
;
; The `icmp eq + br` lowers to `CMP32ri + JNE` (plus the 7c1
; mov-to-next_pc / jmp-dispatcher pair). stage 7c2 replaces the
; CMP+Jcc pair with a mov-only sequence: byte-wise XOR + OR-reduce
; + select_mask_table + per-byte mask-based select that writes the
; predicate-selected target label into next_pc. Result is exit 1
; (the function returns 1 for x == 42, runner calls with x=42).

target triple = "mov-unknown-linux-gnu"

define i32 @is_42(i32 %x) {
  %c = icmp eq i32 %x, 42
  br i1 %c, label %yes, label %no
yes:
  ret i32 1
no:
  ret i32 0
}
