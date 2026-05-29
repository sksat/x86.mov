/* _start for llvm-mov-built canvas examples.
 *
 * Originally `call main; mov ebx, eax; mov eax, 1; int 0x80`, but the
 * `call main` was the *only* non-mov-non-jmp control flow left in the
 * llvm-mov output (everything else gets rewritten by stage 7d3's
 * CALL32d → JMP32d_CALL pass). Per upstream issue #42 ("100% mov+jmp"),
 * we drop the call entirely:
 *
 *   - `_start: jmp main`           — entry transfers to main with no
 *                                    return address pushed.
 *   - `main` calls `int 0x80` (SYS_exit) at its tail via inline asm
 *                                    and never returns. clang emits no
 *                                    `ret` because `__builtin_unreachable`
 *                                    marks the path dead.
 *
 * Net effect on the linked ELF: zero `call` / zero `ret` opcodes,
 * only mov/jmp/int + push/pop (push/pop aren't tracked by the issue's
 * purity gate but they're already in movie86's supported set).
 */

.intel_syntax noprefix
.section .text
.globl _start
_start:
    jmp main
