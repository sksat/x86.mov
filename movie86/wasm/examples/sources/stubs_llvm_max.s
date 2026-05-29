/* Stubs for the max-resolution Mandelbrot (VESA mode 6Ah, 800×600).
 *
 * Same mov-only ABI shape as `stubs_llvm.s` but with a `.fb6Ah` BSS
 * section sized for 800×600 RGBA = 1,920,000 bytes, placed at guest
 * address 0x00400000 via `--section-start=.fb6Ah=0x00400000`.
 */

.intel_syntax noprefix

.section .text

# void set_video_mode(unsigned char mode) — ABI call 0x010.
.globl set_video_mode
set_video_mode:
    mov eax, [esp + 4]
    mov [0x1FFE0010], al
    ret

# void mmap_request(unsigned packed) — ABI call 0x020.
.globl mmap_request
mmap_request:
    mov eax, [esp + 4]
    mov [0x1FFE0020], eax
    ret

/* 800 * 600 * 4 = 1,920,000 bytes RGBA framebuffer. */
.section .fb6Ah, "aw", @nobits
.globl _fb6Ah_region
_fb6Ah_region:
.skip 1920000
