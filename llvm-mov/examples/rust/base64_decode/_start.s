.intel_syntax noprefix
.section .text
.global _start
_start:
    call base64_decode_main
    mov  ebx, eax
    mov  eax, 1
    int  0x80
