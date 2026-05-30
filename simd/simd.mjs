// SIMD86 deck runtime — Single Instruction, Multiple Decks.
//
// Loads a deck ELF (a mov-only flipbook built by build-deck.sh) into the
// movie86 emulator and drives it: an rAF step loop, mode-13h framebuffer
// → canvas blit, and keyboard input gated to canvas hover. The deck guest
// itself does the slide logic (poll input, move index, blit the current
// slide) — this module is just the browser harness around movie86.
//
// movie86 is imported from its deployed sibling namespace (/movie86/), the
// same cross-subproject pattern explorer uses, so we don't duplicate the
// ~110 KB wasm. On x86.mov and on PR previews the absolute path resolves;
// movie86.mjs's own `./build/browser/...` fetches stay under /movie86/.
import { loadVm, modeForNumber, attachKeyboard } from '/movie86/movie86.mjs';

/**
 * Run a deck in `canvas`, returning a handle with `stop()` and the live
 * `vm` (for a future "hand off to turbo86" button).
 *
 * @param {HTMLCanvasElement} canvas
 * @param {string} deckUrl  URL of the deck ELF (e.g. './deck.elf')
 * @param {object} [opts]
 * @param {number} [opts.batch=2_000_000]  guest insns stepped per frame
 * @param {(s:{steps:bigint,mode:number|undefined,halt:string|undefined})=>void} [opts.onStatus]
 */
export async function runDeck(canvas, deckUrl, opts = {}) {
    const res = await fetch(deckUrl);
    if (!res.ok) throw new Error(`fetch ${deckUrl}: ${res.status}`);
    const bytes = new Uint8Array(await res.arrayBuffer());
    const vm = await loadVm(bytes);

    // Keyboard → guest input queue, but only while the pointer is over the
    // canvas. The deck maps Right/Space/PageDown → next, Left/PageUp →
    // prev, Home/End → ends (see deck.c); movie86 just delivers the codes.
    const detach = attachKeyboard(vm, canvas);

    const ctx = canvas.getContext('2d');
    const batch = BigInt(opts.batch ?? 2_000_000);
    let imageData = null;
    let curMode = -1;
    let raf = 0;

    function render() {
        const mode = modeForNumber(vm.activeVideoMode);
        if (!mode) return;
        if (curMode !== mode.modeNumber) {
            canvas.width = mode.width;
            canvas.height = mode.height;
            imageData = ctx.createImageData(mode.width, mode.height);
            curMode = mode.modeNumber;
        }
        const fb = vm.readMem(mode.addr, mode.byteLength);
        if (fb.length === mode.byteLength) {
            imageData.data.set(fb);
            ctx.putImageData(imageData, 0, 0);
        }
    }

    function frame() {
        if (!vm.haltReason) vm.stepN(batch);
        render();
        opts.onStatus?.({ steps: vm.steps, mode: vm.activeVideoMode, halt: vm.haltReason });
        raf = requestAnimationFrame(frame);
    }
    raf = requestAnimationFrame(frame);

    return {
        vm,
        stop() {
            cancelAnimationFrame(raf);
            detach();
            vm.free();
        },
    };
}
