/* Stage 7b1 visibility — bitwise ops without arithmetic.
 *
 * Compiles to AND + XOR + OR chains that all go through the stage
 * 7b1 byte-table rewrites. After legalize the `.text` should contain
 * only mov-family opcodes for the actual computation; the only
 * non-mov mnemonics remaining are the prologue/epilogue
 * (push/pop/sub/ret) and the dispatcher's jmp.
 *
 * `(0xCAFE & 0xBABE) | (0xCAFE ^ 0xBABE)` evaluates to
 * 0xCAFE | 0xBABE = 0xFAFE = 64254. Truncated to a byte exit code
 * that's 0xFE = 254. */
int main(void) {
    int x = 0xCAFE;
    int y = 0xBABE;
    return (x & y) | (x ^ y);
}
