; Stage-3 regression fixture (codex P1 #2 follow-up): `lshr i32 %x, 24` on a
; stack-passed formal arg. DAGCombiner used to fold this into a narrow
; sextload/zextload from FrameIndex; we disable shouldReduceLoadWidth so
; the load stays as a plain MOV32rm + SHR32ri.
;
; 0x2A000000 (= 704643072) >> 24 = 0x2A = 42.

target triple = "mov-unknown-linux-gnu"

define i32 @shift_byte(i32 %x) {
  %r = lshr i32 %x, 24
  ret i32 %r
}
