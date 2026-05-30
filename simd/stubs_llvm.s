.intel_syntax noprefix
.section .text

# mov-only ABI stubs for an llvm-mov-built SIMD86 deck. Unlike the
# movfuscator flavour there's no master_loop / SIGILL dispatch: llvm-mov
# emits ordinary jmp control flow, so the deck runs natively on turbo86
# (and on movie86) without the signal-handler wiring movfuscator needs.
# See github issue about running movfuscator output natively on turbo86.
#
# Cross-engine contract: addresses match movie86::abi_host + turbo86
# runner.abiCall* exactly.

# void set_video_mode(unsigned char mode) — ABI call 0x010.
.globl set_video_mode
set_video_mode:
    mov eax, [esp + 4]
    mov [0x1FFE0010], al
    ret

# void mmap_request(unsigned packed) — ABI call 0x020.
#   packed = (addr & 0xFFFFF000) | (pages - 1), pages in 1..4096.
.globl mmap_request
mmap_request:
    mov eax, [esp + 4]
    mov [0x1FFE0020], eax
    ret

# int poll_input(void) — ABI call 0x040. Triggers a poll by writing any
# byte to [0x1FFE_0040]; the engine pops one key code off its input
# queue and returns it in eax (KEY_NONE = 0 when empty), which carries
# straight into the cdecl return.
.globl poll_input
poll_input:
    mov [0x1FFE0040], al
    ret

# void exit(int code) — ABI call 0x0FE. Used by the bench deck to stop
# at the last slide; the real deck loops forever and never calls it.
.globl exit
exit:
    mov eax, [esp + 4]
    mov [0x1FFE00FE], eax

# 320*200*4 = 256000 byte framebuffer BSS at 0xA0000 via --section-start.
.section .fb13h, "aw", @nobits
.globl _fb13h_region
_fb13h_region:
.skip 256000
