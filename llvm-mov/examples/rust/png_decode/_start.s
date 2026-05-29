.intel_syntax noprefix
.section .text
.global _start
_start:
    call main
    # mov-only ABI exit (call 0x0FE).
    mov  [0x1FFE00FE], eax
