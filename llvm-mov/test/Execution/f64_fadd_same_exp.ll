; Stage 7h4 codex-review P1 regression. When the operands have the
; same exponent the alignment shift amount is 0; the original
; `emitLshrI64ByI32` / `emitShlI64ByI32` clamped the cross-half
; shift count from 32 down to 31, so a `lshr X, 0` could spuriously
; OR `Hi << 31` into the result and corrupt the sticky-check round-
; trip. Pick a mantissa whose hi i32 has bit 0 set (= bit 32 of the
; pre-add 56-bit guarded mantissa MAG = (mant_raw | implicit-1) << 3
; is set iff mant_raw bit 29 is set), so the corruption manifests
; absent the fix.
;
;   value = 0x3FF0000020000000 = 1.0 + 2^-23 ≈ 1.0000001192
;   v + v = 2 × v = 2.000000238... → fptosi (truncate toward 0) → 2

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i64 %ab) {
  %a = bitcast i64 %ab to double
  %r = fadd double %a, %a
  %x = fptosi double %r to i32
  ret i32 %x
}
