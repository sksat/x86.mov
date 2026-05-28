; Stage-7a1+ PoC fixture — first reg-reg ADD that lowers to a pure
; mov-only byte-chain sequence.
;
; ADD32rr extends the ADD32ri rewrite (add42.ll) with one extra
; per-function spill slot (rhs_buf) — the per-byte RHS read becomes
; `mov dl, byte ptr [rhs_buf + i]` instead of the compile-time
; `mov dl, IMM8` slice. Same epilogue / save_ecx / save_edx / srcdst /
; idx machinery as add42.
;
; After stage 7d the only non-mov opcode in this fixture's `.text` is
; `jmp` (the dispatcher / call-continuation indirect branch, gate-
; accepted as mov-equivalent). The earlier-stage non-mov opcodes
; (push, pop, sub, ret) have all been legalised by 7d0/7d1/7d2/7d3
; and no longer appear in the linked ELF. See `add_rr.expect`.

target triple = "mov-unknown-linux-gnu"

define i32 @add_rr(i32 %a, i32 %b) {
  %r = add i32 %a, %b
  ret i32 %r
}
