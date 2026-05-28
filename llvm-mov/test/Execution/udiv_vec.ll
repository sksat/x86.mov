; Stage 7f2 regression — `udiv <N x i32>` must still trigger the
; helper-injection scan even though the type isn't scalar i32 at the
; point of the scan. The driver's Scalarizer (stage 6d1) runs AFTER
; injection and rewrites each lane into a scalar `udiv i32`; those
; lanes then expand to `call __udivsi3`. If the injection scan only
; looked at `isIntegerTy(32)` (and not the vector element type) the
; helper symbols wouldn't be defined in the module and the ELF
; wouldn't link.
;
; udiv_vec_lane_1(100, 7) → second lane of <100/7, 100/7> = 14.
; Both lanes carry the same value so result == 14 regardless of which
; lane is read; the test still exercises the vector → scalar codegen
; path that the regression is about.

target triple = "mov-unknown-linux-gnu"

define i32 @udiv_vec_lane_1(i32 %a, i32 %b) {
  %va0 = insertelement <2 x i32> poison, i32 %a, i32 0
  %va  = insertelement <2 x i32> %va0,   i32 %a, i32 1
  %vb0 = insertelement <2 x i32> poison, i32 %b, i32 0
  %vb  = insertelement <2 x i32> %vb0,   i32 %b, i32 1
  %q   = udiv <2 x i32> %va, %vb
  %e   = extractelement <2 x i32> %q, i32 1
  ret i32 %e
}
