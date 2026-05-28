/* Stage 7a + 7c1 + 7c4 visibility — a small Fibonacci loop.
 *
 * The loop body has 3 add operations and the loop header has a signed
 * compare (cmp + jl). After 7c4 this fixture exercises:
 *
 *   - 7a1 ADD32rr legalize (the t/a/b updates)
 *   - 7c1 CFG dispatcher (every BB ends with `mov [next_pc], target;
 *     jmp .Ldispatcher`)
 *   - 7c4 signed-predicate legalize (cmp + jl on the loop bound is
 *     rewritten via the byte-SUB chain + SF/OF/ZF flag math)
 *
 * After 7c4 the `.text` shows no `cmp` / `jl` — only the dispatcher's
 * `jmp`. main returns fib(10) = 55. */
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
