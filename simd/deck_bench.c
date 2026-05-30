/* Benchmark variant of deck.c — identical flip logic, but it calls
 * exit(0) the moment it reaches the last slide, so a harness can queue
 * (n_slides - 1) Right keys, run it to completion, and time the whole
 * "boot + initial draw + (n-1) native blits" pass. Used by the turbo86
 * native-speed measurement (the real deck loops forever, which can't be
 * timed to an Exit). Not shipped.
 */

#define FB_ADDR  0xA0000
#define SLIDE_W  320
#define SLIDE_H  200
#define SLIDE_PX (SLIDE_W * SLIDE_H)

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
extern void exit(int code);

extern const unsigned int slides_data[];
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

        if (idx != prev) {
            show(&slides_data[(unsigned)idx * SLIDE_PX]);
            if (idx == n_slides - 1) {
                exit(0); /* bench: stop once we've blitted the last slide */
            }
        }
    }

    return 0;
}
