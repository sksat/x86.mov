/* _start for llvm-mov-built canvas examples.
 *
 * Originally `call main; mov [0x1FFE00FE], eax`. The `call main` was
 * the only non-mov-non-jmp control flow left in the linked ELF
 * (everything else gets rewritten by llvm-mov stage 7d3's CALL32d →
 * JMP32d_CALL pass). Per upstream issue #42 ("100% mov+jmp"), the
 * fix:
 *
 *   - `_start: jmp main`        — entry transfers to main with no
 *                                 return address pushed.
 *   - `main` calls a `noreturn` `exit(int)` stub at its tail that
 *                                 writes to the ABI-exit page
 *                                 (0x1FFE00FE), so clang elides the
 *                                 epilogue `ret`.
 *
 * Net effect: .text has zero `call` and zero `ret` opcodes.
 */

.intel_syntax noprefix
.section .text
.globl _start
_start:
    jmp main
