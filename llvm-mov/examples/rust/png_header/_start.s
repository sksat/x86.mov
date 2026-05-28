# Tiny _start for the png_header demo. Calls png_header_main and uses
# its return value as the exit code.

.intel_syntax noprefix

.section .text
.global _start
_start:
    call png_header_main
    mov  ebx, eax       # exit code = IHDR.width & 0xff
    mov  eax, 1         # __NR_exit
    int  0x80
