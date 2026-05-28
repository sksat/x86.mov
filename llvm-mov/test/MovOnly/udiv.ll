; Stage 7f2 mov-only assert for `udiv`. The SDAG-Expand path emits a
; `call __udivsi3` which the existing 7d3 CALL legalize rewrites into
; the dispatcher `jmp` shape — so the `.text` of this fixture, with
; the injected `__udivsi3` body now present, contains only
; mov + jmp (no `call`, no `idiv`, no `udiv`).
;
; Pre-7f2 this fixture wouldn't even link (the SDAG libcall would
; emit `call __udivsi3` against an undefined symbol).

target triple = "mov-unknown-linux-gnu"

define i32 @udivide(i32 %n, i32 %d) {
  %q = udiv i32 %n, %d
  ret i32 %q
}
