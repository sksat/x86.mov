# Tiny _start for the jpeg_header demo.

.intel_syntax noprefix

.section .text
.global _start
_start:
    call jpeg_header_main
    mov  ebx, eax       # exit code = parsed SOF0 height & 0xff
    mov  eax, 1         # __NR_exit
    int  0x80
