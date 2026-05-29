.intel_syntax noprefix
.section .text
.global _start
_start:
    call main
    mov  [0x1FFE00FE], eax
