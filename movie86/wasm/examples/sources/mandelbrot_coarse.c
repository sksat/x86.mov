/* Real (mov-only via movfuscator) Mandelbrot fractal.
 *
 * Compiled by movfuscator's `rcc -target=x86/mov`, statically linked
 * against the movfuscator runtime (crt0_cf.o + crtf_cf.o + crtd_cf.o +
 * softfloat32.o) plus a tiny stubs.s providing exit / sigaction /
 * set_video_mode.
 *
 * Fixed-point Q16.16 maths, escape-time iteration.
 *
 * Performance note: every C statement becomes hundreds of mov-only x86
 * instructions, and each of those becomes hundreds of master-loop
 * iterations under movie86. So we compute at a coarse 80×50 grid and
 * blit each cell as a 4×4 block of mode 13h pixels — the final image
 * still fills the 320×200 canvas but compute cost is 1/16th. Even so,
 * a full run takes tens of millions of guest instructions and many
 * minutes of wall time under movie86; that's the cost of "real
 * computation through a mov-only emulator".
 */

#define FB_ADDR  0xA0000   /* mode 13h base */
#define FB_W     320
#define CW       80        /* compute grid width  (CW * 4 == FB_W) */
#define CH       50        /* compute grid height (CH * 4 == 200)  */
#define MAX_ITER 8

typedef int fp_t;   /* Q16.16 */

extern void set_video_mode(unsigned mode);
extern void mmap_request(unsigned packed);

/* Pack (addr, pages) for the mov-only ABI mmap_request call. */
#define ABI_MMAP_PACK(addr, pages) ((unsigned)(addr) | (unsigned)((pages) - 1))

/* mode 13h FB: 0xA0000 + ceil(256000 / 4096) = 63 pages.
 * Round up to 64 = next power of two for human-readable packing. */
#define FB13H_MMAP ABI_MMAP_PACK(0x000A0000U, 64)

static fp_t fmul(fp_t a, fp_t b)
{
    long long p;
    p = (long long)a * (long long)b;
    return (fp_t)(p >> 16);
}

int main(void)
{
    unsigned *fb;
    int py, px, i, dy, dx;
    fp_t cx, cy, x, y, xx, yy, xy;
    unsigned color, t;

    mmap_request(FB13H_MMAP);
    set_video_mode(0x13);
    fb = (unsigned *)FB_ADDR;

    /* Window: re in [-2.5, 1.5], im in [-1.25, 1.25].
     * Q16.16 steps for the coarse compute grid:
     *   step_re = 4.0 * 65536 / CW = 3276    ; CW=80
     *   step_im = 2.5 * 65536 / CH = 3276    ; CH=50
     * (re_min, im_min) = (-2.5, -1.25) * 65536 = (-163840, -81920)
     */
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
                /* RGBA u32 LE: bytes R, G, B, A
                 * teal → yellow ramp:
                 *   R = t  ;  G = t  ;  B = 255 - t  ;  A = 0xFF
                 */
                color = (0xFFu << 24) | ((255u - t) << 16) | (t << 8) | t;
            }
            /* Blit a 4×4 block per compute pixel. */
            for (dy = 0; dy < 4; dy++) {
                for (dx = 0; dx < 4; dx++) {
                    fb[(py * 4 + dy) * FB_W + (px * 4 + dx)] = color;
                }
            }
        }
    }

    return 0;
}
