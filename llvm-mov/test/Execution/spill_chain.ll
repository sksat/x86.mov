; Stage-4b fixture: high register pressure + reg-shift forces RA to spill.
; This is exactly codex's stage-3.5 review reproducer that used to abort
; in Greedy RA (stage 3.5 caught it with the report_fatal_error
; intercept on storeRegToStackSlot). Now PEI inserts a real MOV32mr/rm
; spill via the storeRegToStackSlot hook + EBX/ESI/EDI back in the
; CSR set.
;
; Math: sh = a0 << a1; result = sh + (a2+a3) + (a3+a4) + (a4+a5)
;       = sh + a2 + 2·a3 + 2·a4 + a5
;       with (1, 3, 2, 4, 8, 8) → 8 + 2 + 8 + 16 + 8 = 42.

target triple = "mov-unknown-linux-gnu"

define i32 @spill_chain(i32 %a0, i32 %a1, i32 %a2, i32 %a3, i32 %a4, i32 %a5) {
  %k0 = add i32 %a2, %a3
  %k1 = add i32 %a3, %a4
  %k2 = add i32 %a4, %a5
  %sh = shl i32 %a0, %a1
  %u0 = add i32 %sh, %k0
  %u1 = add i32 %u0, %k1
  %u2 = add i32 %u1, %k2
  ret i32 %u2
}
