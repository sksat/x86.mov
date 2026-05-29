# Stage-7h7 runtime: call mandelbrot_main and exit with its low-byte
# return value as the syscall status.

.intel_syntax noprefix

.section .text
.global _start
_start:
    call mandelbrot_main
    mov  ebx, eax       # mandelbrot_main()'s i32 return → exit status
    mov  eax, 1         # __NR_exit
    int  0x80           # never returns
