.intel_syntax noprefix
.section .text

# mov-only ABI stubs. Both functions write to the unmapped ABI page
# (0x1FFE_0000); the engine catches the resulting SIGSEGV (turbo86)
# or routes via AbiHost (movie86) and dispatches by page offset.
# Cross-engine contract: matches `movie86::abi_host` constants and
# `turbo86/runner.abiCall*` exactly.

# void set_video_mode(unsigned char mode)
#   ABI call 0x010 — writes `mode` to [0x1FFE_0010] (1-byte store).
.globl set_video_mode
set_video_mode:
    mov eax, [esp + 4]
    mov [0x1FFE0010], al
    ret

# void mmap_request(unsigned packed)
#   ABI call 0x020 — packed = (addr & 0xFFFFF000) | (pages - 1).
#   pages in 1..4096 (size 4 KiB .. 16 MiB).
.globl mmap_request
mmap_request:
    mov eax, [esp + 4]
    mov [0x1FFE0020], eax
    ret

# 320*200*4 = 256000 byte BSS at 0xA0000 via --section-start.
# Kept so movie86's wasm Vm pre-maps the FB through PT_LOAD (its
# FlatMemory is fixed at load time); turbo86 still needs the
# mmap_request call above because its stub mmap is static.
.section .fb13h, "aw", @nobits
.globl _fb13h_region
_fb13h_region:
.skip 256000
