/* SIMD86 — Single Instruction, Multiple Decks.
 *
 * A slide deck that is *executed*, not rendered by a runtime: this C is
 * compiled mov-only by movfuscator and run inside movie86. Every pixel
 * that reaches the screen is produced by `mov`.
 *
 * The slides themselves are plain image data (raw RGBA, one 320x200
 * frame per slide), linked in via deck_data.s. This program is just the
 * flipbook: poll the keyboard, move an index, and blit the current
 * slide to the mode-13h framebuffer when the index changes.
 *
 * movie86's input ABI is generic key codes; the slide *meaning* lives
 * here — Right / Space / PageDown advance, Left / PageUp go back, Home
 * / End jump to the ends. Drawing happens only on a change, so the poll
 * loop stays cheap under the emulator.
 *
 * Built by the movfuscator pipeline — see build-deck.sh.
 */

#define FB_ADDR  0xA0000 /* mode 13h base */
#define SLIDE_W  320
#define SLIDE_H  200
#define SLIDE_PX (SLIDE_W * SLIDE_H)

/* movie86 generic key codes (core::abi_host KEY_*). */
#define KEY_NONE      0x00
#define KEY_SPACE     0x20
#define KEY_LEFT      0x80
#define KEY_RIGHT     0x81
#define KEY_PAGE_UP   0x84
#define KEY_PAGE_DOWN 0x85
#define KEY_HOME      0x86
#define KEY_END       0x87

extern void set_video_mode(unsigned mode);
extern void mmap_request(unsigned packed);
extern int poll_input(void);

/* Slide image data + count, supplied by deck_data.s (generated). */
extern const unsigned int slides_data[]; /* n_slides * SLIDE_PX pixels */
extern const int n_slides;

#define ABI_MMAP_PACK(addr, pages) ((unsigned)(addr) | (unsigned)((pages) - 1))
#define FB13H_MMAP ABI_MMAP_PACK(0x000A0000U, 64)

static void show(const unsigned int *slide)
{
    unsigned int *fb = (unsigned int *)FB_ADDR;
    int i;
    for (i = 0; i < SLIDE_PX; i++) {
        fb[i] = slide[i];
    }
}

int main(void)
{
    int idx, prev, k;

    mmap_request(FB13H_MMAP);
    set_video_mode(0x13);

    idx = 0;
    show(&slides_data[0]);

    for (;;) {
        k = poll_input();
        prev = idx;

        if (k == KEY_RIGHT || k == KEY_SPACE || k == KEY_PAGE_DOWN) {
            if (idx < n_slides - 1) {
                idx++;
            }
        }
        if (k == KEY_LEFT || k == KEY_PAGE_UP) {
            if (idx > 0) {
                idx--;
            }
        }
        if (k == KEY_HOME) {
            idx = 0;
        }
        if (k == KEY_END) {
            idx = n_slides - 1;
        }

        if (idx != prev) {
            show(&slides_data[(unsigned)idx * SLIDE_PX]);
        }
    }

    return 0;
}
