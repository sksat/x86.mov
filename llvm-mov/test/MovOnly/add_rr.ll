; Stage-7a1+ PoC fixture — first reg-reg ADD that lowers to a pure
; mov-only byte-chain sequence.
;
; ADD32rr extends the ADD32ri rewrite (add42.ll) with one extra
; per-function spill slot (rhs_buf) — the per-byte RHS read becomes
; `mov dl, byte ptr [rhs_buf + i]` instead of the compile-time
; `mov dl, IMM8` slice. Same epilogue / save_ecx / save_edx / srcdst /
; idx machinery as add42.
;
; The objdump gate checks that the only non-mov opcodes in this
; function are the four prologue/epilogue mnemonics that stage 7d
; will eliminate (push, pop, sub, ret), listed in add_rr.expect.

target triple = "mov-unknown-linux-gnu"

define i32 @add_rr(i32 %a, i32 %b) {
  %r = add i32 %a, %b
  ret i32 %r
}
