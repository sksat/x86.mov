# hello — write(1, "Hello\n", 6) + exit(0).
#
# Two syscalls; the second exits explicitly so the guest doesn't fall
# off the end of the code segment. The string lives at a `msg` label
# *after* the code, addressed by `mov ecx, OFFSET msg` so the linker
# resolves it to the rebased absolute address.
.intel_syntax noprefix
.text
.global _start
_start:
    mov edx, 6          # count
    mov ecx, OFFSET msg # buf
    mov ebx, 1          # fd = stdout
    mov eax, 4          # SYS_write
    int 0x80
    mov ebx, 0          # status
    mov eax, 1          # SYS_exit
    int 0x80
msg:
    .ascii "Hello\n"
