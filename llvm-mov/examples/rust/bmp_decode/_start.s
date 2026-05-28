# Tiny _start for the bmp_decode demo. Calls bmp_decode_main and
# uses its return value (full-pixel-stream digest mod 256) as the
# exit code.

.intel_syntax noprefix

.section .text
.global _start
_start:
    call bmp_decode_main
    mov  ebx, eax       # exit = pixel digest & 0xff
    mov  eax, 1         # __NR_exit
    int  0x80
