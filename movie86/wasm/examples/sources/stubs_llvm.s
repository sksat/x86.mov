.intel_syntax noprefix
.section .text

.globl set_video_mode
set_video_mode:
    mov eax, [esp + 4]
    int 0x10
    # `ret` rewritten to `pop ecx ; jmp ecx` so .text has no ret opcode
    # (upstream issue #42). movie86 added FF /4 mod=11 (`jmp r32`) for
    # exactly this case; see decode.rs `decode_ff_group`.
    pop ecx
    jmp ecx

# `exit(int status)` — Linux SYS_exit. Doesn't return (kernel never
# hands control back) so no `ret` needed; this is critical for the
# issue #42 "no ret in .text" goal — main's call to exit is mov-only
# via llvm-mov stage 7d3's CALL32d → JMP32d_CALL rewrite, and the
# called function itself terminates the process.
.globl exit
exit:
    mov eax, 1
    mov ebx, [esp + 4]
    int 0x80

# 320*200*4 = 256000 byte BSS at 0xA0000 via --section-start
.section .fb13h, "aw", @nobits
.globl _fb13h_region
_fb13h_region:
.skip 256000
