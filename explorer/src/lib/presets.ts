// Bundled C snippets — quick-start examples wired into the source
// editor's preset menu. They load editable source you then Compile and
// Run (the "run what you compiled" intent) — distinct from the removed
// pre-built *fixture* dropdown. Most stay short; `mandelbrot` is the
// deliberate heavyweight that shows real computation driving the
// embedded Canvas pane through the mov-only ABI.

export interface Preset {
    id: string;
    label: string;
    source: string;
    /** Named link recipe for presets that need more than the bare
     *  `_start.o + <user>.o` static link (llvm-mov path only). See
     *  `explorer.mjs`'s `LINK_PROFILES`. `'canvas13h'` links the
     *  mov-only ABI framebuffer stubs and pins a `.fb13h` BSS section
     *  at the VGA base 0xA0000 so a mode-13h program renders in the
     *  Canvas pane. Omit for plain compute / printf examples. */
    linkProfile?: 'canvas13h';
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
    {
        id: 'fizzbuzz',
        label: 'fizzbuzz — classic 1..30',
        source: `#include <stdio.h>

int main(void) {
    int i;
    for (i = 1; i <= 30; i++) {
        if (i % 15 == 0)      printf("FizzBuzz\\n");
        else if (i % 3 == 0)  printf("Fizz\\n");
        else if (i % 5 == 0)  printf("Buzz\\n");
        else                  printf("%d\\n", i);
    }
    return 0;
}
`,
    },
    {
        id: 'fib',
        label: 'fib — n-th Fibonacci (recursive)',
        // Recursive on purpose: each `call fib` becomes llvm-mov
        // stage-7d3's CALL32d → JMP32d_CALL mov-only rewrite, so the
        // IR / asm panes show how a mov-only target fakes a call stack
        // with no real `call`/`ret`. (An iterative two-accumulator loop
        // is faster and avoids the ~177 recursive calls of fib(10), but
        // hides that — swap it in if you'd rather show the loop form.)
        source: `int fib(int n) {
    if (n < 2) return n;
    return fib(n - 1) + fib(n - 2);
}

int main(void) {
    return fib(10);  /* expect exit code 55 */
}
`,
    },
    {
        id: 'mandelbrot',
        label: 'mandelbrot — mode-13h fractal (Canvas)',
        // Runs end-to-end on the llvm-mov path only: it sets VGA mode 13h
        // and writes RGBA pixels into the framebuffer the canvas13h link
        // profile pins at guest 0xA0000, which the embedded Canvas pane
        // renders. Fixed-point Q16.16 escape-time iteration. Heavy: every
        // C statement becomes hundreds of mov-only instructions and each
        // of those hundreds of master-loop iterations, so it computes a
        // coarse 80×50 grid blitted as 4×4 blocks — still many millions
        // of guest instructions and minutes of wall time. That cost *is*
        // the demo: real computation through a mov-only emulator.
        linkProfile: 'canvas13h',
        source: `/* Mode-13h Mandelbrot — fixed-point Q16.16, escape-time iteration.
 * The .fb13h framebuffer at 0xA0000 + the set_video_mode / mmap_request
 * / exit stubs are supplied by the explorer's canvas13h link profile. */
#define FB_ADDR  0xA0000   /* mode 13h base */
#define FB_W     320
#define CW       80        /* compute grid width  (CW * 4 == FB_W) */
#define CH       50        /* compute grid height (CH * 4 == 200)  */
#define MAX_ITER 8

typedef int fp_t;          /* Q16.16 */

extern void set_video_mode(unsigned mode);
extern void mmap_request(unsigned packed);
extern void exit(int code) __attribute__((noreturn));

/* Pack (addr, pages) for the mov-only ABI mmap_request call. */
#define ABI_MMAP_PACK(addr, pages) ((unsigned)(addr) | (unsigned)((pages) - 1))
#define FB13H_MMAP ABI_MMAP_PACK(0x000A0000U, 64)

static fp_t fmul(fp_t a, fp_t b) {
    long long p = (long long)a * (long long)b;
    return (fp_t)(p >> 16);
}

int main(void) {
    unsigned *fb;
    int py, px, i, dy, dx;
    fp_t cx, cy, x, y, xx, yy, xy;
    unsigned color, t;

    mmap_request(FB13H_MMAP);
    set_video_mode(0x13);
    fb = (unsigned *)FB_ADDR;

    /* Window re∈[-2.5,1.5], im∈[-1.25,1.25]; Q16.16 step 3276/cell. */
    for (py = 0; py < CH; py++) {
        cy = -81920 + py * 3276;
        for (px = 0; px < CW; px++) {
            cx = -163840 + px * 3276;
            x = 0; y = 0;
            for (i = 0; i < MAX_ITER; i++) {
                xx = fmul(x, x);
                yy = fmul(y, y);
                if (xx + yy > (4 << 16)) break;
                xy = fmul(x, y);
                x = xx - yy + cx;
                y = xy + xy + cy;
            }
            if (i >= MAX_ITER) {
                color = 0xFF000000u;   /* interior — opaque black */
            } else {
                t = (unsigned)i * (256u / MAX_ITER);
                if (t > 255u) t = 255u;
                /* teal → yellow ramp, RGBA u32 LE */
                color = (0xFFu << 24) | ((255u - t) << 16) | (t << 8) | t;
            }
            /* Blit a 4×4 block per compute pixel. */
            for (dy = 0; dy < 4; dy++)
                for (dx = 0; dx < 4; dx++)
                    fb[(py * 4 + dy) * FB_W + (px * 4 + dx)] = color;
        }
    }

    exit(0);
    return 0;  /* unreachable */
}
`,
    },
];

export const DEFAULT_PRESET = PRESETS[1]; // hello
