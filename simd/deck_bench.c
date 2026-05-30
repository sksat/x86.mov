/* Benchmark variant of deck.c — identical slide-table flip logic, but it
 * calls exit(0) the moment it reaches the last slide, so a harness can
 * queue (n_slides - 1) Right keys, run it to completion, and time the
 * whole "boot + initial draw + (n-1) blits (incl. the resolution change)"
 * pass. Used by the turbo86 native-speed measurement
 * (turbo86/runner/deck_bench_test.go); the real deck loops forever, which
 * can't be timed to an Exit. Not shipped.
 */

extern void set_video_mode(unsigned mode);
extern void mmap_request(unsigned packed);
extern int poll_input(void);
extern void exit(int code);

extern const unsigned char slides_data[];
extern const int n_slides;
extern const unsigned int slide_mode[];
extern const unsigned int slide_addr[];
extern const unsigned int slide_npix[];
extern const unsigned int slide_off[];

#define KEY_NONE  0x00
#define KEY_SPACE 0x20
#define KEY_LEFT  0x80
#define KEY_RIGHT 0x81

#define ABI_MMAP_PACK(addr, pages) ((unsigned)(addr) | (unsigned)((pages) - 1))

static unsigned pages_for(unsigned bytes)
{
    return (bytes + 0xFFF) >> 12;
}

static void show(int i)
{
    unsigned int *fb = (unsigned int *)(unsigned long)slide_addr[i];
    const unsigned int *src = (const unsigned int *)(slides_data + slide_off[i]);
    int n = slide_npix[i];
    int k;
    for (k = 0; k < n; k++) {
        fb[k] = src[k];
    }
}

int main(void)
{
    int idx, prev, k, i, cur_mode;

    for (i = 0; i < n_slides; i++) {
        mmap_request(ABI_MMAP_PACK(slide_addr[i], pages_for(slide_npix[i] * 4)));
    }

    idx = 0;
    cur_mode = (int)slide_mode[0];
    set_video_mode(slide_mode[0]);
    show(0);
    if (n_slides == 1) {
        exit(0);
    }

    for (;;) {
        k = poll_input();
        prev = idx;
        if (k == KEY_RIGHT || k == KEY_SPACE) {
            if (idx < n_slides - 1) {
                idx++;
            }
        }
        if (k == KEY_LEFT) {
            if (idx > 0) {
                idx--;
            }
        }
        if (idx != prev) {
            if ((int)slide_mode[idx] != cur_mode) {
                cur_mode = (int)slide_mode[idx];
                set_video_mode(slide_mode[idx]);
            }
            show(idx);
            if (idx == n_slides - 1) {
                exit(0); /* bench: stop once we've blitted the last slide */
            }
        }
    }

    return 0;
}
