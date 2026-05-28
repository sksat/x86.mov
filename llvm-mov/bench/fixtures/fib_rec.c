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
 * fib(10) = 55. The runner doesn't pass argc/argv to main so the
 * computed exit code is non-deterministic; the bench measures static
 * shape + average runtime, neither of which depends on the exact
 * result.
 */
int fib(int n) {
    if (n < 2) return n;
    return fib(n - 1) + fib(n - 2);
}

int main(void) {
    return fib(10);
}
