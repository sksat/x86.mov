; Stage 7e — count-leading-zeros (CTLZ).
;
; ctlz(0x00001234) = 19. Binary 0000…0001 0010 0011 0100 — 19 leading
; zeros before the first set bit at position 12. Passed as a cdecl
; arg so it can't be constant-folded; the intrinsic call routes
; through the new CTLZ32r pseudo + byte-table lowering.

target triple = "mov-unknown-linux-gnu"

declare i32 @llvm.ctlz.i32(i32, i1)

define i32 @clz(i32 %x) {
  %r = call i32 @llvm.ctlz.i32(i32 %x, i1 false)
  ret i32 %r
}
