; Stage 7e mov-only assert for `llvm.cttz.i32`. Symmetric to ctlz.ll
; — the CTTZ32r pseudo + byte-table lowering scans LSB→MSB through
; `__mov_ctz_or_8_table`.

target triple = "mov-unknown-linux-gnu"

declare i32 @llvm.cttz.i32(i32, i1)

define i32 @ctz(i32 %x) {
  %r = call i32 @llvm.cttz.i32(i32 %x, i1 false)
  ret i32 %r
}
