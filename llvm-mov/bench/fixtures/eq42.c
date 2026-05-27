/* Stage 7c2 visibility — pure EQ/NE comparison. The branch lowers to
 * CMP32ri + JNE which the 7c2 pass collapses into a mov-only sequence
 * (byte-XOR + OR-reduce + select_mask_table + per-byte select into
 * next_pc). After 7c2 the `.text` should have no `cmp` and no `je/jne`,
 * only the dispatcher's `jmp [next_pc]` for the indirect branch. */
int main(void) {
    int x = 42;
    if (x == 42) return 1;
    return 0;
}
