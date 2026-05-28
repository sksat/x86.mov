; Stage-7d3 PoC fixture — `call <user-func>` lowers to a mov-only
; sequence + a direct `JMP32d_CALL` terminator.
;
; The CALL32d MI in `caller`'s prologue body gets rewritten by
; MovOnlyLegalize::legalizeCallSites into:
;   - mov [esp - 4], offset L_after           ; return label
;   - mov eax, offset __mov_esp_dec_scratch
;   - <byte-chain SUB esp by 4 in the .bss scratch>
;   - mov esp, [eax]                            ; esp = esp_caller - 4
;   - jmp <callee>                              ; JMP32d_CALL
;   L_after:                                    ; continuation MBB symbol
;
; The objdump gate counts the trailing `jmp <callee>` as a `jmp` (which
; the .expect file already whitelists), so this fixture passes once 7d3
; runs.

target triple = "mov-unknown-linux-gnu"

define i32 @add2(i32 %x) {
  %r = add i32 %x, 2
  ret i32 %r
}

define i32 @caller(i32 %x) {
  %y = call i32 @add2(i32 %x)
  ret i32 %y
}
