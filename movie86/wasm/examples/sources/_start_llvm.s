.intel_syntax noprefix
.section .text
.globl _start
_start:
    call main
    # mov-only ABI exit (call 0x0FE): eax = main()'s return value.
    # Replaces `mov ebx, eax ; mov eax, 1 ; int 0x80` so the
    # toolchain-generated _start can't ever surface an `int` to the
    # engine — turbo86 catches the SIGSEGV on this mov and emits
    # Outbound{Exit{code}}, movie86 routes via AbiHost::abi_call →
    # Fault::Exit.
    mov [0x1FFE00FE], eax
