# Stage-6e runtime: tiny _start that invokes indirect_call_main and
# exits with its return value. Same `int 0x80` shape as the other
# examples' _start.s — the inner indirect call lives inside `apply`,
# not here.

.intel_syntax noprefix

.section .text
.global _start
_start:
    call indirect_call_main
    mov  ebx, eax       # indirect_call_main()'s return → exit status
    mov  eax, 1         # __NR_exit
    int  0x80           # never returns
