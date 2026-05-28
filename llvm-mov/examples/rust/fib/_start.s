# Stage-7d3 runtime: tiny _start that invokes fib_main and exits with
# its return value (fib(10) = 55).

.intel_syntax noprefix

.section .text
.global _start
_start:
    call fib_main
    mov  ebx, eax       # fib_main()'s return → exit status
    mov  eax, 1         # __NR_exit
    int  0x80           # never returns
