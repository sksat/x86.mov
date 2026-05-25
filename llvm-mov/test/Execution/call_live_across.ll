; Stage-6a fixture: codex's stage-6 design pass flagged "CALL needs
; call-preserved regmask" as the #1 trap — without it, RA leaves live
; values in EAX/ECX/EDX across the call and the callee silently clobbers
; them. Simple caller→callee→ret doesn't expose this; we need a value
; computed *before* the call and used *after*.
;
; Structure (mul-free since we don't have IMUL yet):
;   k  = x << 1            ; pre-call live value (2*x)
;   r1 = identity(x)        ; call clobbers caller-saved regs
;   ret r1 + k              ; uses k *after* the call
;
; With x = 14:  k = 28; identity(14) = 14; result = 14 + 28 = 42.
;
; If the regmask doesn't pin EBX/ESI/EDI as preserved, RA may pick
; EAX/ECX/EDX for `%k`, the callee mutates that register, and we
; return garbage instead of 42.

target triple = "mov-unknown-linux-gnu"

define internal i32 @identity(i32 %a) {
  ret i32 %a
}

define i32 @caller(i32 %x) {
  %k  = shl i32 %x, 1
  %r1 = call i32 @identity(i32 %x)
  %r  = add i32 %r1, %k
  ret i32 %r
}
