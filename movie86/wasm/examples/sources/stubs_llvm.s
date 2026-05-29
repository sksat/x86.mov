.intel_syntax noprefix
.section .text
.globl set_video_mode
set_video_mode:
    mov eax, [esp + 4]
    int 0x10
    ret

# 320*200*4 = 256000 byte BSS at 0xA0000 via --section-start
.section .fb13h, "aw", @nobits
.globl _fb13h_region
_fb13h_region:
.skip 256000
