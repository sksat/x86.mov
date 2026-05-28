/* Stage 7b2 / 7b3 visibility — shift-heavy bit manipulation.
 *
 * Exercises:
 *   - SHL32ri (`x << 4`)        — legalized via __mov_shl_byte_k tables
 *   - SHR32ri (`x >> 1`)        — __mov_shr_byte_k tables
 *
 * `argc` is the runtime LHS (prevents constant folding); the constants
 * are picked so the bench only measures shapes, not exit codes.
 *
 * Written in C89 (declarations before statements) because the
 * movfuscator side's LCC frontend rejects C99 mixed decl/code, and we
 * want a fair side-by-side build.
 */
int main(int argc, char **argv) {
    int x;
    int y;
    int s;
    (void)argv;
    x = argc << 4;     /* SHL32ri */
    y = (x | 0x32);
    s = y >> 1;        /* SHR32ri */
    return (s << 1) | (y & 0xFF);
}
