.intel_syntax noprefix
.section .text
.global _start
_start:
    call qoi_decode_main
    mov  ebx, eax
    mov  eax, 1
    int  0x80
