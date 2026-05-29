# hello — write(1, "Hello\n", 6) + exit(0), int-free.
#
# Same shape as before, but the int 0x80 calls have been replaced
# by writes to the mov-only ABI page (see movie86::abi_host):
#   call 0x080 = write   (args in ebx/ecx/edx, same as SYS_write)
#   call 0x0FE = exit    (eax = exit code)
.intel_syntax noprefix
.text
.global _start
_start:
    mov edx, 6                # count
    mov ecx, OFFSET msg       # buf
    mov ebx, 1                # fd = stdout
    mov eax, 4                # SYS_write marker (handler ignores, kept for symmetry)
    mov [0x1FFE0080], eax     # ABI write (call 0x080)
    mov eax, 0                # exit code
    mov [0x1FFE00FE], eax     # ABI exit (call 0x0FE)
msg:
    .ascii "Hello\n"
