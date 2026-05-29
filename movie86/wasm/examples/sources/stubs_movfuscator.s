/* Minimal stubs for a movfuscator-output binary running under movie86,
 * plus a `.fb13h` BSS region that the demo's mode 13h canvas reads from.
 *
 * sigaction        — return 0 success. movie86 wires SIGSEGV → dispatch
 *                    and SIGILL → master_loop directly from the ELF
 *                    symbol table, so we don't actually install handlers.
 *
 * exit(status)     — mov-only ABI call 0x0FE. cdecl ABI:
 *                    movfuscator's jmp_extern pushes the args, so
 *                    [esp+4] = status. Writes the 32-bit value to
 *                    the ABI page; both engines route that to
 *                    Fault::Exit / Outbound::Exit (replaces the
 *                    earlier `int 0x80 SYS_exit` epilogue).
 *
 * set_video_mode(mode)
 *                  — mov-only ABI call 0x010. Writes mode to the
 *                    unmapped page at 0x1FFE_0010; movie86 routes
 *                    that to AbiHost::abi_call → active_video_mode,
 *                    turbo86 catches the SIGSEGV and emits a
 *                    VideoMode outbound event. Replaces the older
 *                    int 0x10 / AH=0 BIOS convention.
 *
 * mmap_request(packed)
 *                  — mov-only ABI call 0x020. packed encodes
 *                    (addr | (pages - 1)). On movie86 wasm this is
 *                    a no-op (FB is pre-mapped via PT_LOAD); on
 *                    turbo86 it actually ptrace-injects an mmap2 so
 *                    subsequent FB writes don't EFAULT.
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
    movl 4(%esp), %eax
    movl %eax, 0x1FFE00FE

.globl set_video_mode
.type set_video_mode, @function
set_video_mode:
    movl 4(%esp), %eax
    movb %al, 0x1FFE0010
    ret

.globl mmap_request
.type mmap_request, @function
mmap_request:
    movl 4(%esp), %eax
    movl %eax, 0x1FFE0020
    ret

/* 320 × 200 × 4 bytes RGBA framebuffer, BSS-like. */
.section .fb13h, "aw", @nobits
.globl _fb13h_region
_fb13h_region:
.skip 256000
