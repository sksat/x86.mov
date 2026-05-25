# Stage-6.5 runtime: tiny _start that invokes rust_main and exits with
# its return value. Same `int 0x80` shape as the synthesised _start
# the execution-test runner generates (see ../../test/Execution/run.sh).
# Lives separately here so the Rust example is self-contained.

.intel_syntax noprefix

.section .text
.global _start
_start:
    call rust_main
    mov  ebx, eax       # rust_main()'s return → exit status
    mov  eax, 1         # __NR_exit
    int  0x80           # never returns
