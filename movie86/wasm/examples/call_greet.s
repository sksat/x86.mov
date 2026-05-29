# call_greet — `main` calls `greet`, `greet` writes "Hi!\n" + ret,
# `main` then exits 0.
#
# Exercises the i386 stack: `call greet` pushes the return EIP,
# `greet`'s body runs, `ret` pops and lands back in `main`. Both
# movie86 and turbo86 must agree on the stack layout for this to work.
.intel_syntax noprefix
.text
.global _start
_start:
    call greet
    mov ebx, 0          # status
    mov eax, 1          # SYS_exit
    int 0x80
greet:
    mov edx, 4          # count
    mov ecx, OFFSET msg # buf
    mov ebx, 1          # fd = stdout
    mov eax, 4          # SYS_write
    int 0x80
    ret
msg:
    .ascii "Hi!\n"
