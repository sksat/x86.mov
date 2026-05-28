; Stage 7f — 32-bit multiply via MUL32rr pseudo + byte-table lowering.
;
; multiply(7, 6) = 42. Both operands come in as cdecl args so neither
; side can be constant-folded; the IR-level `mul` selects to MUL32rr
; and gets schoolbook'd into 4-byte partial products + accumulator.

target triple = "mov-unknown-linux-gnu"

define i32 @multiply(i32 %a, i32 %b) {
  %r = mul i32 %a, %b
  ret i32 %r
}
