; Stage-3.5 fixture: i8 formal argument + i8 return.
;
; Caller pushes 298 (= 0x12A) as i32 cdecl. Callee's i8 view is the low
; byte = 0x2A = 42. Codex's stage-3.5 review specifically called for
; `id8(298)` instead of `id8(42)`: the latter has high bits = 0 so a
; bug that forgot to TRUNCATE on the load wouldn't be visible in the
; SDValue type chain. With 298, the load returns i32 0x12A but the IR
; consumer expects i8 — without the TRUNCATE in LowerFormalArguments
; SelectionDAGBuilder trips.

target triple = "mov-unknown-linux-gnu"

define i8 @id8(i8 %x) {
  ret i8 %x
}
