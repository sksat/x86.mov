# return42 — exit(42) via SYS_exit (int 0x80 syscall 1).
#
# Three instructions, no data. Smallest fixture that exercises the
# int-0x80 syscall trap path on both engines.
.intel_syntax noprefix
.text
.global _start
_start:
    mov ebx, 42      # status
    mov eax, 1       # SYS_exit
    int 0x80
