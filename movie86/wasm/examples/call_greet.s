# call_greet — `main` calls `greet`, `greet` writes "Hi!\n" + ret,
# `main` then exits 0. int-free via mov-only ABI (see hello.s).
#
# Still exercises the i386 stack: `call greet` pushes the return EIP,
# `greet`'s body runs, `ret` pops and lands back in `main`. Both
# movie86 and turbo86 must agree on the stack layout for this to work.
.intel_syntax noprefix
.text
.global _start
_start:
    call greet
    mov eax, 0                # exit code
    mov [0x1FFE00FE], eax     # ABI exit
greet:
    mov edx, 4                # count
    mov ecx, OFFSET msg       # buf
    mov ebx, 1                # fd = stdout
    mov eax, 4                # SYS_write marker
    mov [0x1FFE0080], eax     # ABI write
    ret
msg:
    .ascii "Hi!\n"
