/* Generic button-input demo — a colored block you steer with the
 * keyboard, compiled mov-only by movfuscator and run under movie86.
 *
 * The point is to exercise the *input* half of the mov-only ABI
 * (`poll_input` → `CALL_POLL_INPUT`, offset 0x040) the same way the
 * canvas examples exercise the output half. It is deliberately NOT a
 * slideshow: movie86's input is generic key codes, so this demo just
 * maps arrow keys → motion and Space → colour. Higher layers (simd)
 * are the ones that decide "Right means next slide".
 *
 * Drawing is incremental — only the moved block is erased + repainted,
 * and only when a key actually arrives — so the per-frame mov count
 * stays tiny even though movfuscator turns every C statement into
 * hundreds of mov instructions. A full-screen redraw each poll would
 * crawl under the emulator.
 *
 * Input only registers while the mouse hovers the canvas (the JS side
 * gates keydown on hover); off-canvas keystrokes stay with the page.
 *
 * Built by the movfuscator pipeline — see build-input-demo.sh.
 */

#define FB_ADDR 0xA0000 /* mode 13h base */
#define FB_W    320
#define FB_H    200

/* Generic key codes — the movie86 KEY_* alphabet (core::abi_host).
 * Printable keys arrive as their ASCII byte; Space is 0x20. */
#define KEY_NONE  0x00
#define KEY_SPACE 0x20
#define KEY_LEFT  0x80
#define KEY_RIGHT 0x81
#define KEY_UP    0x82
#define KEY_DOWN  0x83

/* RGBA u32, little-endian byte order R,G,B,A (matches the canvas
 * examples + JS putImageData). 0xAABBGGRR. */
#define BLACK 0xFF000000u /* opaque black */
#define GREEN 0xFF00FF00u /* opaque green */
#define BLUE  0xFFFF0000u /* opaque blue  */

#define BLK  16 /* block edge, pixels */
#define STEP 8  /* pixels moved per keypress */

extern void set_video_mode(unsigned mode);
extern void mmap_request(unsigned packed);
extern int poll_input(void);

/* Pack (addr, pages) for the mov-only ABI mmap_request call. */
#define ABI_MMAP_PACK(addr, pages) ((unsigned)(addr) | (unsigned)((pages) - 1))
/* mode 13h FB: 0xA0000, 256000 B = 63 pages, rounded to 64. */
#define FB13H_MMAP ABI_MMAP_PACK(0x000A0000U, 64)

static void fill_block(unsigned *fb, int x, int y, unsigned color)
{
    int dy, dx;
    for (dy = 0; dy < BLK; dy++) {
        for (dx = 0; dx < BLK; dx++) {
            fb[(y + dy) * FB_W + (x + dx)] = color;
        }
    }
}

int main(void)
{
    unsigned *fb;
    int x, y, px, py, k;
    unsigned color;

    mmap_request(FB13H_MMAP);
    set_video_mode(0x13);
    fb = (unsigned *)FB_ADDR;

    x = (FB_W - BLK) / 2;
    y = (FB_H - BLK) / 2;
    px = x;
    py = y;
    color = GREEN;

    fill_block(fb, x, y, color);

    for (;;) {
        k = poll_input();

        if (k == KEY_LEFT) {
            x -= STEP;
        }
        if (k == KEY_RIGHT) {
            x += STEP;
        }
        if (k == KEY_UP) {
            y -= STEP;
        }
        if (k == KEY_DOWN) {
            y += STEP;
        }
        if (k == KEY_SPACE) {
            color = (color == GREEN) ? BLUE : GREEN;
        }

        /* Keep the block on screen. */
        if (x < 0) {
            x = 0;
        }
        if (x > FB_W - BLK) {
            x = FB_W - BLK;
        }
        if (y < 0) {
            y = 0;
        }
        if (y > FB_H - BLK) {
            y = FB_H - BLK;
        }

        /* Only repaint when something happened — keep the poll loop
         * cheap (no full-screen redraw per iteration). */
        if (k != KEY_NONE) {
            fill_block(fb, px, py, BLACK);
            fill_block(fb, x, y, color);
            px = x;
            py = y;
        }
    }

    return 0;
}
