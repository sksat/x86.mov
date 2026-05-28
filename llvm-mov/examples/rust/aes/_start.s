# Stage-8+ runtime: tiny _start that invokes aes_main and exits with
# its return value (XOR of the ciphertext bytes after N_ROUNDS
# encrypts).

.intel_syntax noprefix

.section .text
.global _start
_start:
    call aes_main
    mov  ebx, eax       # aes_main()'s return → exit status
    mov  eax, 1         # __NR_exit
    int  0x80           # never returns
