.intel_syntax noprefix
.section .text
.global _start
_start:
    call dep_mov_add_main
    mov  ebx, eax       # exit code = triv_add(40, 2) = 42
    mov  eax, 1         # __NR_exit
    int  0x80
