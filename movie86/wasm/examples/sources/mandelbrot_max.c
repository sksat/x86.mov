/* Mandelbrot at VESA VBE 1.0 mode 6Ah's full 800×600, no shortcut.
 *
 * Same C structure as mandelbrot_hires.c, just bigger constants and a
 * different framebuffer slot. Compiled by `clang -O2` → `llvm-mov-llc`
 * (the movfuscator pipeline would be days of wall time on this).
 *
 * Performance: 480,000 pixels × MAX_ITER=24 ≈ 70 B+ movie86 steps at
 * the ~50 K steps/px movfuscator-on-movie86 baseline. Expect
 * ~8 hours of wall time in a typical browser tab — leave it overnight
 * and check in the morning. The active mode's canvas updates
 * progressively, so Follow mode is genuinely watchable for the first
 * few rows; for the full image, batch mode + a high refresh interval
 * is the sane way to run it.
 */

#define FB_ADDR  0x00400000    /* VESA 6Ah base — see FRAMEBUFFER_MODES */
#define W        800
#define H        600
#define MAX_ITER 24

typedef int fp_t;

extern void set_video_mode(unsigned mode);

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

    set_video_mode(0x6A);
    fb = (unsigned *)FB_ADDR;

    /* Window: re in [-2.5, 1.5], im in [-1.25, 1.25].
     * Q16.16 steps:
     *   step_re = 4.0 * 65536 / 800 = 327
     *   step_im = 2.5 * 65536 / 600 = 273
     */
    for (py = 0; py < H; py++) {
        cy = -81920 + py * 273;
        for (px = 0; px < W; px++) {
            cx = -163840 + px * 327;
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

    return 0;
}
