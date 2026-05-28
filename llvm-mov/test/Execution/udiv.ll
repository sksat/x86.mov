; Stage 7f2 — `udiv i32` lowering via SDAG Expand → `call __udivsi3`,
; whose body is injected by the llvm-mov-llc driver as IR. The injected
; function is a restoring 32-iteration bit-by-bit long division.
;
; udivide(100, 7) = 14. Both operands flow in as cdecl args so neither
; side can be constant-folded; SDAG sees an `ISD::UDIV` it has marked
; Expand → libcall → `call __udivsi3 (n, d)`.
;
; Pre-stage-7f2 link would fail with "undefined reference to
; `__udivsi3'" unless the user crate provided a stub. The driver
; injection removes that requirement.

target triple = "mov-unknown-linux-gnu"

define i32 @udivide(i32 %n, i32 %d) {
  %q = udiv i32 %n, %d
  ret i32 %q
}
