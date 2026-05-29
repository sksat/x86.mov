/* Stubs for the max-resolution Mandelbrot (VESA mode 6Ah, 800×600).
 *
 * Same shape as `stubs_llvm.s` but with a `.fb6Ah` BSS section sized
 * for 800×600 RGBA = 1,920,000 bytes, placed at guest address
 * 0x00400000 via `--section-start=.fb6Ah=0x00400000`.
 */

.intel_syntax noprefix

.section .text
.globl set_video_mode
set_video_mode:
    mov eax, [esp + 4]
    int 0x10
    /* `ret` rewritten to `pop ecx ; jmp ecx` — see stubs_llvm.s. */
    pop ecx
    jmp ecx

/* See stubs_llvm.s for the issue #42 rationale: noreturn exit() means
 * main's tail-call to it (rewritten to mov-only by llvm-mov 7d3)
 * eliminates the last `ret` from .text. */
.globl exit
exit:
    mov eax, 1
    mov ebx, [esp + 4]
    int 0x80

/* 800 * 600 * 4 = 1,920,000 bytes RGBA framebuffer. */
.section .fb6Ah, "aw", @nobits
.globl _fb6Ah_region
_fb6Ah_region:
.skip 1920000
