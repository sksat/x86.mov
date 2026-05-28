; Stage 7e — count-set-bits (popcount).
;
; popcount(0xDEADBEEF) = 24 (3+3+2+3+3+3+3+4 over the four nibble pairs).
; The input is passed as a cdecl arg so it can't be constant-folded; the
; intrinsic call is required to lower through the target's CTPOP path.

target triple = "mov-unknown-linux-gnu"

declare i32 @llvm.ctpop.i32(i32)

define i32 @popcount(i32 %x) {
  %r = call i32 @llvm.ctpop.i32(i32 %x)
  ret i32 %r
}
