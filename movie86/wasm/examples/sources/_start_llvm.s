.intel_syntax noprefix
.section .text
.globl _start
_start:
    call main
    mov ebx, eax
    mov eax, 1
    int 0x80
