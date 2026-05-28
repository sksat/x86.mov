/* Stage 7d1 / 7d3 visibility — recursive fibonacci.
 *
 * The 7d1 return-address slot `__mov_return_addr_slot` is a SINGLE
 * global cell shared across all functions and call frames. Smart-
 * friend's design review flagged "ra in a single slot will break
 * recursion" as the top trap — the safety invariant is that each
 * `ret` writes its own RA into the slot THEN immediately jumps,
 * before any nested call can return. Recursive fib() stresses this
 * by stacking up multiple in-flight call frames; if the slot model
 * were wrong, the recursive descent would mis-jump.
 *
 * Also exercises:
 *   - 7d3 (CALL legalize) twice per recursion level
 *   - 7c4 (signed predicate `n < 2`)
 *   - 7a1 (ADD32rr on the return-value sum)
 *
 * fib(24) = 46368 — chosen so the wall-clock runtime stays well
 * above the bare process-exit overhead (~150 µs) on both back-ends.
 * fib(10), which earlier versions of this fixture used, finished in
 * sub-millisecond and made the runtime column dominated by exec()
 * cost rather than the mov-only computation it's meant to compare.
 * The exit code wraps the i32 to a byte (46368 mod 256 = 224), but
 * the bench doesn't check it — only static shape + average runtime
 * matter here.
 */
int fib(int n) {
    if (n < 2) return n;
    return fib(n - 1) + fib(n - 2);
}

int main(void) {
    return fib(24);
}
