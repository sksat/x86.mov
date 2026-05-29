.intel_syntax noprefix
.section .text

# mov-only ABI stubs. All three functions write to the unmapped ABI
# page (0x1FFE_0000); the engine catches the resulting SIGSEGV
# (turbo86) or routes via AbiHost (movie86) and dispatches by page
# offset. Cross-engine contract: matches `movie86::abi_host` constants
# and `turbo86/runner.abiCall*` exactly.
#
# `ret` is rewritten to `pop ecx ; jmp ecx` so the linked ELF's .text
# carries zero ret opcodes (upstream issue #42). The `jmp ecx` is FF /4
# mod=11 — see movie86 decode.rs `decode_ff_group`. `exit` doesn't
# need a ret at all: the ABI store unmaps the process before the next
# instruction is fetched.

# void set_video_mode(unsigned char mode)
#   ABI call 0x010 — writes `mode` to [0x1FFE_0010] (1-byte store).
.globl set_video_mode
set_video_mode:
    mov eax, [esp + 4]
    mov [0x1FFE0010], al
    pop ecx
    jmp ecx

# void mmap_request(unsigned packed)
#   ABI call 0x020 — packed = (addr & 0xFFFFF000) | (pages - 1).
#   pages in 1..4096 (size 4 KiB .. 16 MiB).
.globl mmap_request
mmap_request:
    mov eax, [esp + 4]
    mov [0x1FFE0020], eax
    pop ecx
    jmp ecx

# void exit(int code)   __attribute__((noreturn))
#   ABI call 0x0FE — writes `code` to [0x1FFE_00FE] (4-byte store).
# The engine never lets the next instruction execute, so we can leave
# the function without a ret / pop+jmp tail. This is what main calls
# at its tail to avoid clang emitting a ret in its own epilogue.
.globl exit
exit:
    mov eax, [esp + 4]
    mov [0x1FFE00FE], eax

# 320*200*4 = 256000 byte BSS at 0xA0000 via --section-start.
# Kept so movie86's wasm Vm pre-maps the FB through PT_LOAD (its
# FlatMemory is fixed at load time); turbo86 still needs the
# mmap_request call above because its stub mmap is static.
.section .fb13h, "aw", @nobits
.globl _fb13h_region
_fb13h_region:
.skip 256000
