.intel_syntax noprefix
.section .text
.globl _start
_start:
    call main
    # mov-only ABI exit (call 0x0FE) with main()'s return value in eax.
    # The real deck loops forever and never returns here; this is the
    # path the bench deck takes after exit(), and a safety net otherwise.
    mov [0x1FFE00FE], eax
