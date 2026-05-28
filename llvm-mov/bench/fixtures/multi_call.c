/* Stage 7d3 visibility — multiple sequential calls in the same
 * basic block. The 7d3 rewrite splits the MBB at each `CALL32d`
 * and the legalizer must re-enter the continuation block to catch
 * later calls (codex P2 review on 7d3). This fixture lands several
 * sequential calls inside `main` so the bench's `.text` shape
 * directly reflects the per-call mov-chain cost.
 *
 * Also exercises:
 *   - 7a1 (ADD32rr / ri on the accumulator chain)
 *
 * Written in C89 (declarations before statements) because the
 * movfuscator side's LCC frontend rejects C99 mixed decl/code.
 */
int bump(int x) {
    return x + 1;
}

int main(int argc, char **argv) {
    int a;
    int b;
    int c;
    (void)argv;
    a = bump(argc);
    b = bump(a);
    c = bump(b);
    return a + b + c;
}
