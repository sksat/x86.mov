// Bundled C snippets — quick-start examples wired into the source
// editor's preset menu. Kept short on purpose; deeper examples (md5,
// mandelbrot) live in the per-compiler subprojects already.

export interface Preset {
    id: string;
    label: string;
    source: string;
}

export const PRESETS: readonly Preset[] = [
    {
        id: 'return42',
        label: 'return 42 — exit code 42',
        source: `int main(void) { return 42; }
`,
    },
    {
        id: 'hello',
        label: 'hello — write "Hello, mov!\\n"',
        source: `#include <stdio.h>

int main(void) {
    printf("Hello, mov!\\n");
    return 0;
}
`,
    },
    {
        id: 'sum10',
        label: 'sum10 — sum 1..10 via for-loop',
        source: `int main(void) {
    int sum = 0;
    int i;
    for (i = 1; i <= 10; i++) sum = sum + i;
    return sum;
}
`,
    },
    {
        id: 'prime',
        label: 'prime — primes ≤ 100',
        source: `#include <stdio.h>

int is_prime(int x) {
    int i;
    if (x < 2) return 0;
    for (i = 2; i * i <= x; i++)
        if (x % i == 0) return 0;
    return 1;
}

int main(void) {
    int i;
    for (i = 2; i <= 100; i++)
        if (is_prime(i)) printf("%d ", i);
    printf("\\n");
    return 0;
}
`,
    },
];

export const DEFAULT_PRESET = PRESETS[1]; // hello
