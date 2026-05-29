# return42 — exit(42) via SYS_exit (int 0x80 syscall 1).
#
# Three instructions, no data. Smallest fixture that exercises the
# int-0x80 syscall trap path on both engines. **Deliberately not
# migrated to the mov-only ABI** — keeps a tiny canary for the legacy
# `int 0x80` path that movie86 still supports for compatibility with
# older committed binaries (see movie86/wasm/CLAUDE.md). The "first
# 5 bytes are `BB 2A 00 00 00` (mov ebx, 42)" property is asserted
# by several handover / round-trip tests, so don't change the prologue
# without updating them in lock-step.
.intel_syntax noprefix
.text
.global _start
_start:
    mov ebx, 42      # status
    mov eax, 1       # SYS_exit
    int 0x80
