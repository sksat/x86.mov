; Stage-7d3 regression — two sequential calls in the same source
; block. Stage 7d3's MBB-split rewrite advances the outer loop to
; the continuation MBB so the second CALL also gets legalised.
; Without that advance (codex P2 review on 7d3), the second `call`
; would survive in `.text` and break the mov-only gate here.

target triple = "mov-unknown-linux-gnu"

define i32 @id(i32 %x) {
  ret i32 %x
}

define i32 @caller(i32 %x) {
  %a = call i32 @id(i32 %x)
  %b = call i32 @id(i32 %a)
  ret i32 %b
}
