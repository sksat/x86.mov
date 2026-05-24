# Hand-written _start runtime for execution tests.
#
# Why this exists: we don't want the test pipeline to depend on the CI
# runner's 32-bit dynamic loader or libc. So instead of linking the
# generated `.o` against crt1.o + glibc, we link it against this tiny
# static runtime.
#
# `main`'s return value comes back in EAX (cdecl), and we pass it to
# the Linux i386 `exit` syscall (nr 1). int 0x80 keeps things static
# and self-contained — no PLT, no loader.

.intel_syntax noprefix

.section .text
.global _start
_start:
    call main
    mov  ebx, eax       # exit status from main()
    mov  eax, 1         # __NR_exit
    int  0x80           # never returns
