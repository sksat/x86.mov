; Stage 7e mov-only assert for `llvm.ctpop.i32`.
;
; Pre-stage-7e the SDAG Expand path generates SWAR Hamming-weight
; (x - ((x >> 1) & 0x55…), …) — the SUB32rr in step 1 leaks `sub` to
; .text because MovOnlyLegalize only knows SUB32ri. Stage 7e replaces
; the Expand path with a Custom byte-table lowering whose only opcodes
; are MOV32{ri,rm,mr}, MOV8rm_idx, ADD32 (byte-chained) — no SUB.

target triple = "mov-unknown-linux-gnu"

declare i32 @llvm.ctpop.i32(i32)

define i32 @popcount(i32 %x) {
  %r = call i32 @llvm.ctpop.i32(i32 %x)
  ret i32 %r
}
