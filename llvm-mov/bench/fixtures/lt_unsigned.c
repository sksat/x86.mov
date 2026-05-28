/* Stage 7c3 visibility — unsigned `<` comparison.
 *
 * Uses `argc` (a non-constant function argument) to prevent LLVM from
 * constant-folding the comparison at IR time. With both operands of
 * the compare being a constant we'd lose the predicate entirely —
 * `x < UINT_MAX` in particular folds to `x != UINT_MAX` and lowers
 * to CMP + JNE, falling into the stage 7c2 EQ/NE pipeline. With a
 * runtime LHS the IR keeps `icmp ult` and SelectionDAG lowers it to
 * CMP32ri + JB, which is what 7c3 targets.
 *
 * Stage 7c3 (this commit) rewrites the CMP+JB pair into a mov-only
 * sequence:
 *
 *   - byte SUB chain via __mov_sub8_{diff,borrow}_table — the
 *     final borrow_out (CF) lands in CL after byte 3.
 *   - select_mask_table[CF] turns the {0,1} CF byte into a
 *     {0x00, 0xFF} mask.
 *   - per-byte mask-select writes the chosen target into next_pc.
 *
 * After 7c3 the `.text` shows no `cmp` / `jb` — only the
 * dispatcher's `jmp`.
 *
 * The runner doesn't pass real argc/argv to main (no CRT), so the
 * computed exit code is non-deterministic. The bench measures static
 * code shape + average runtime, neither of which depends on the
 * exact result. */
int main(int argc, char **argv) {
    (void)argv;
    if ((unsigned)argc < 10u) return 1;
    return 0;
}
