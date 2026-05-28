/* opt 6 follow-up visibility — register-amount shifts (`x << n`,
 * `x >> n` where `n` is a runtime value). The signed shifts lower
 * to SHL32rCL and SAR32rCL; the unsigned `>>` is what surfaces
 * SHR32rCL specifically. All three flow through the same heavy
 * mov-only rewrite — `legalizeShift32rCL`, a 5-stage power-of-2
 * unroll that historically emitted 50 redundant `mov dword [idx],
 * 0` instructions per site. The "Phase 5 idx-zero hoist" follow-up
 * to opt 6 turns those 50 into 1 (the invariant is identical to
 * opt 6's CMP+Jcc Phase 5 hoist: nothing inside the unrolled loop
 * writes idx[2..3], so a single hoisted MOV32mi is enough).
 *
 * `argc` keeps the LHS runtime so DAGCombine can't fold the shift;
 * the amount is also derived from `argc` so it stays in CL and we
 * hit the rCL path, not the ri path. Combining SHL (`<<`), SAR
 * (signed `>>`), and SHR (unsigned `>>` on `unsigned int`) in the
 * same fixture exercises all three legalize entry points and lets
 * the bench surface the per-site savings in one row.
 *
 * C89 (declarations before statements) — movfuscator's LCC
 * frontend rejects mixed declarations, and we keep the fixture
 * apples-to-apples across the bench backends.
 */
int main(int argc, char **argv) {
    int x;
    int y;
    int s;
    unsigned u;
    int amt;
    (void)argv;
    amt = argc & 7;             /* runtime amount, kept in [0, 7] */
    x = argc << amt;            /* SHL32rCL */
    y = (x | 0x32);
    s = y >> amt;               /* SAR32rCL (signed int >>) */
    u = (unsigned)y >> amt;     /* SHR32rCL (unsigned >>) */
    return (s ^ (int)u) | (y & 0xFF);
}
