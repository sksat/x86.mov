; Stage-6c+ indirect-call mov-only gate. After CALL32r legalize lands,
; the indirect call is rewritten into the 7d3 byte-chain + a
; `JMP32r_CALL <reg>` terminator (objdump renders as `jmp *%reg`).
; The objdump gate already allows `jmp`, so this fixture only needs
; that opcode in .expect.

target triple = "mov-unknown-linux-gnu"

define internal i32 @add25(i32 %x) {
  %r = add i32 %x, 25
  ret i32 %r
}

@indirect_target = global ptr @add25

define i32 @caller(i32 %x) {
  %fp = load volatile ptr, ptr @indirect_target
  %r = call i32 %fp(i32 %x)
  ret i32 %r
}
