; Stage 7f — `mul i32 %x, 7` selects to MUL32ri (immediate form).
; The byte tables are still consulted but the imm bytes feed
; directly into the lookup-index pack (no second-operand spill).

target triple = "mov-unknown-linux-gnu"

define i32 @mul7(i32 %x) {
  %r = mul i32 %x, 7
  ret i32 %r
}
