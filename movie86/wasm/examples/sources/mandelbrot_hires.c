/* Mandelbrot at mode 13h's native 320×200, no coarse-blit shortcut.
 *
 * Compiled by `clang -O2` → `llvm-mov-llc` (the movfuscator pipeline
 * is way too slow for the full pixel count — see mandelbrot_coarse.c
 * for the fast / comparison variant).
 *
 * Performance: 64,000 pixels × MAX_ITER=24 ≈ 6 B movie86 steps, ~40
 * min wall time in a typical browser tab. Watch it draw row-by-row
 * in Follow mode; in batch mode the canvas fills bottom-to-top over
 * the course of an hour or so. Sharper boundary detail than the
 * coarse variant because of the higher iteration cap.
 */

#define FB_ADDR  0xA0000
#define W        320
#define H        200
#define MAX_ITER 24

typedef int fp_t;

extern void set_video_mode(unsigned mode);
#ifdef __LCC__
extern void exit(int status);
#else
extern void exit(int status) __attribute__((noreturn));
#endif

static fp_t fmul(fp_t a, fp_t b)
{
    long long p;
    p = (long long)a * (long long)b;
    return (fp_t)(p >> 16);
}

int main(void)
{
    unsigned *fb;
    int py, px, i;
    fp_t cx, cy, x, y, xx, yy, xy;
    unsigned color, t;

    set_video_mode(0x13);
    fb = (unsigned *)FB_ADDR;

    /* Window: re in [-2.5, 1.5], im in [-1.25, 1.25].
     *   step_re = 4.0   * 65536 / 320 = 819
     *   step_im = 2.5   * 65536 / 200 = 819
     */
    for (py = 0; py < H; py++) {
        cy = -81920 + py * 819;
        for (px = 0; px < W; px++) {
            cx = -163840 + px * 819;
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
                color = 0xFF000000u;
            } else {
                t = (unsigned)i * (256u / MAX_ITER);
                if (t > 255u) t = 255u;
                color = (0xFFu << 24) | ((255u - t) << 16) | (t << 8) | t;
            }
            fb[py * W + px] = color;
        }
    }

    /* Tail-call exit(0) — see mandelbrot_coarse.c for the issue #42
     * rationale (noreturn-tagged extern + `_start: jmp main` together
     * eliminate call/ret from .text for the llvm-mov build). */
    exit(0);
    return 0;
}
