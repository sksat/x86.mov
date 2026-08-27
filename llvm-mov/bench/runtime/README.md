# Runtime performance benchmarks

This suite complements `codegen-metrics.sh`. Static instruction counts and
`.text` size describe code shape, but are not treated as execution speed.

The workloads cover three levels:

- focused shared-C kernels: bitwise, variable shift, multiply, and bit scan;
- a matched empty loop for estimating kernel-only turbo86 time;
- the existing practical recursive `fib(24)` application at
  `../fixtures/fib_rec.c`.

Every focused kernel runs 100,000 iterations. This keeps native execution
well above process-start noise while remaining practical under movie86.
Select a space-separated subset with `WORKLOADS`, for example:

```sh
WORKLOADS='bitscan empty' RUNS=20 make runtime-bench
```

## Engines and comparisons

- movie86: deterministic dynamic steps from an exit snapshot (and therefore
  a real end-to-end interpreter execution, rather than a static estimate);
- turbo86: native `Run`-to-`Exit` median via `TestRuntimeBenchELF`;
- movfuscator: direct native execution of an ELF compiled from the exact same
  C source as llvm-mov.

The bitscan kernel is an llvm-mov before/after workload only: movfuscator's
C frontend emits unresolved `__builtin_clz`/`__builtin_ctz` calls. Other
kernels retain the exact same-source native comparison.

The turbo86 harness intentionally reports whole-run latency. For a focused
kernel estimate, measure `empty.c` with the same compiler revision and
subtract its median. ELF parsing, segment loading, and Runner construction
are already outside the timer; ptrace start/exit remain inside it.

```sh
TURBO86_RUNTIME_BENCH_ELF=/tmp/kernel.elf \
TURBO86_RUNTIME_BENCH_RUNS=25 \
TURBO86_RUNTIME_BENCH_EXPECTED_STATUS=120 \
TURBO86_RUNTIME_BENCH_TIMEOUT=120s \
  go test ./runner -run '^TestRuntimeBenchELF$' -count=1 -v
```

`run.sh` supplies the expected low-byte result for every workload and rejects
wrong results on movie86, turbo86, and native llvm-mov execution. Upstream
movfuscator's runtime always exits with status 1 instead of preserving
`main`'s return value, so its native preflight verifies termination and that
documented status, but cannot independently validate the kernel result. The
timeout defaults to 120 seconds per turbo86 run and is configurable for slower
hosts.

Use at least 15 runs for `fib(24)`, 25 for kernels, and 51 for the matched
empty loop. Report both adjusted and unadjusted medians: subtraction reduces
fixed overhead, but can magnify noise when a kernel is extremely short.

Upstream movfuscator linked ELFs currently do not complete under movie86 or
turbo86 because their SIGILL master loop lacks a termination condition those
engines can provide. Consequently, llvm-mov before/after comparisons use
movie86 and turbo86, while llvm-mov-vs-movfuscator uses direct native
execution. These are separate experiments and must not be combined into one
speedup number.
