; Stage-2 fixture: identity(255) — sign-extension trap detector. If the
; load ever picks up movsx/movzx instead of mov, 255 would survive but
; -1 (0xFFFFFFFF) wouldn't; this case alone won't catch that, but pinning
; the upper exit-code byte gives the next stage's `-1` IR-level fixture
; something concrete to compare against in CodeGen tests.

target triple = "mov-unknown-linux-gnu"

define i32 @identity(i32 %x) {
  ret i32 %x
}
