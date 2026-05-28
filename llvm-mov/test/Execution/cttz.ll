; Stage 7e — count-trailing-zeros (CTTZ).
;
; cttz(0x00001000) = 12. The single set bit is at position 12; all
; lower bits are zero. Same fixture shape as ctlz.ll but exercising
; the CTTZ32r pseudo (LSB→MSB scan order).

target triple = "mov-unknown-linux-gnu"

declare i32 @llvm.cttz.i32(i32, i1)

define i32 @ctz(i32 %x) {
  %r = call i32 @llvm.cttz.i32(i32 %x, i1 false)
  ret i32 %r
}
