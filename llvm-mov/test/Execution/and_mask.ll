; Stage-3 regression fixture (codex P1 #1 follow-up): `and i32 %x, 255` on a
; stack-passed formal arg. DAGCombiner used to fold this into a narrow
; zextload (8-bit from FrameIndex) that MOV32rm doesn't match; we now
; disable shouldReduceLoadWidth to keep the load full-width.
;
; 0xC0DE2A & 0xFF = 0x2A = 42 — and the upper-byte byte garbage is what
; would have been emitted by the broken form.

target triple = "mov-unknown-linux-gnu"

define i32 @and_mask(i32 %x) {
  %r = and i32 %x, 255
  ret i32 %r
}
