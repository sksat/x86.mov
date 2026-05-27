/* Stage 7a + 7c1 visibility — a small Fibonacci loop.
 *
 * The loop body has 3 add operations and the loop header has a signed
 * compare (cmp + jl), so this fixture exercises:
 *
 *   - 7a1 ADD32rr legalize (the t/a/b updates)
 *   - 7c1 CFG dispatcher (every BB ends with `mov [next_pc], target;
 *     jmp .Ldispatcher`)
 *
 * The signed compare on the loop bound stays as native `cmp + jl` —
 * stage 7c4 (signed predicates) hasn't landed yet, so this fixture
 * surfaces "cmp / jl" in the non-mov mnemonic column. When 7c4 lands
 * the bench-check diff will show those mnemonics dropping out and
 * the mov ratio rising. main returns fib(10) = 55. */
int main(void) {
    int a = 0, b = 1, t;
    int i;
    for (i = 0; i < 10; i++) {
        t = a + b;
        a = b;
        b = t;
    }
    return a;
}
