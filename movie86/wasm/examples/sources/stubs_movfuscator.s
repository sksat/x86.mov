/* Minimal stubs for a movfuscator-output binary running under movie86,
 * plus a `.fb13h` BSS region that the demo's mode 13h canvas reads from.
 *
 * sigaction        — return 0 success. movie86 wires SIGSEGV → dispatch
 *                    and SIGILL → master_loop directly from the ELF
 *                    symbol table, so we don't actually install handlers.
 *
 * exit(status)     — Linux i386 SYS_exit. cdecl ABI:
 *                    movfuscator's jmp_extern pushes the args, so
 *                    [esp+4] = status.
 *
 * set_video_mode(mode)
 *                  — BIOS int 0x10 with AH=0, AL=mode. Same cdecl
 *                    convention as exit. movie86's BiosHost::bios_call
 *                    records the mode number; the demo only renders the
 *                    canvas matching that mode.
 *
 * The `.fb13h` section is `aw` (alloc + write) and `@nobits` (no bytes
 * in the file image), placed at 0xA0000 via `--section-start=.fb13h=0xA0000`
 * at link time. ld emits a PT_LOAD for it; movie86's `flatten_with_stack`
 * picks it up as a writable region the guest can `mov`-write pixels into.
 */

.text

.globl sigaction
.type sigaction, @function
sigaction:
    movl $0, %eax
    ret

.globl exit
.type exit, @function
exit:
    movl $1, %eax
    movl 4(%esp), %ebx
    int  $0x80

.globl set_video_mode
.type set_video_mode, @function
set_video_mode:
    movl 4(%esp), %eax
    int  $0x10
    ret

/* 320 × 200 × 4 bytes RGBA framebuffer, BSS-like. */
.section .fb13h, "aw", @nobits
.globl _fb13h_region
_fb13h_region:
.skip 256000
