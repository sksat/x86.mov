; Stage 7e mov-only assert for `llvm.ctlz.i32`. The new CTLZ32r
; pseudo + byte-table lowering keeps `.text` mov-only modulo the
; dispatcher `jmp`. The previous shift-chain Expand was already
; mov-only here (no SUB leak like CTPOP) but at ~600 mov per site;
; the byte-table form brings that down to ~150 mov per site.

target triple = "mov-unknown-linux-gnu"

declare i32 @llvm.ctlz.i32(i32, i1)

define i32 @clz(i32 %x) {
  %r = call i32 @llvm.ctlz.i32(i32 %x, i1 false)
  ret i32 %r
}
