; Stage 7h4 — larger values to exercise the normalize-after-add
; carry-out path: 1000000 + 1000000 = 2000000.

target triple = "mov-unknown-linux-gnu"

define i32 @rt(i32 %i, i32 %j) {
  %a = sitofp i32 %i to double
  %b = sitofp i32 %j to double
  %r = fadd double %a, %b
  %d = fptosi double %r to i32
  ; pick a distinctive low byte of 2000000 = 0x1E8480 → 0x80 = 128
  %x = and i32 %d, 255
  ret i32 %x
}
