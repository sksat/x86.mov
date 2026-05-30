// SIMD86 deck runtime — Single Instruction, Multiple Decks.
//
// Loads a deck ELF (a mov-only flipbook built by build-deck.sh) into the
// movie86 emulator and drives it: an rAF step loop, framebuffer → canvas
// blit, and keyboard input gated to canvas hover. The deck guest itself
// does the slide logic (poll input, move index, set_video_mode on a
// resolution change, blit the current slide) — this module is just the
// browser harness.
//
// "Acceleration boost": hand the live session off to a local turbo86 over
// WebSocket so the deck runs at native speed. We keep the local movie86 Vm
// around as a display buffer + mode tracker — turbo86's MemUpdate frames
// are written back into it via writeMem and its VideoMode events via
// setActiveVideoMode, so the SAME render path shows either engine. Keys go
// to turbo86 as proto.KeyInput while boosted, back to the local Vm
// otherwise.
//
// movie86 is imported from its deployed sibling namespace (/movie86/), the
// same cross-subproject pattern explorer uses, so we don't duplicate the
// ~110 KB wasm.
import {
    loadVm,
    modeForNumber,
    attachKeyboard,
    snapshotContext,
    makeLoadContextMessage,
    makeKeyInputMessage,
    parseOutboundMessage,
} from '/movie86/movie86.mjs';

// Human-readable name for a movie86 KEY_* code (for the input log).
// Printable ASCII shows as itself; the navigation block gets words.
const KEY_NAMES = {
    0x08: 'Backspace', 0x0d: 'Enter', 0x1b: 'Esc', 0x20: 'Space',
    0x80: '←', 0x81: '→', 0x82: '↑', 0x83: '↓',
    0x84: 'PageUp', 0x85: 'PageDown', 0x86: 'Home', 0x87: 'End',
};
function keyName(code) {
    if (KEY_NAMES[code]) return KEY_NAMES[code];
    if (code >= 0x21 && code <= 0x7e) return String.fromCharCode(code);
    return `0x${code.toString(16)}`;
}

/**
 * Run a deck in `canvas`. Returns a handle:
 *   - `vm`           the live movie86 Vm
 *   - `stop()`       tear down (rAF + keyboard + WS + Vm)
 *   - `boost(url?)`  hand off to a local turbo86 for native speed
 *   - `engine()`     'local' | 'turbo86'
 *
 * @param {HTMLCanvasElement} canvas
 * @param {string} deckUrl  URL of the deck ELF (e.g. './deck.elf')
 * @param {object} [opts]
 * @param {number} [opts.batch=2_000_000]  guest insns stepped per local frame
 * @param {string} [opts.turbo86Url='ws://127.0.0.1:1234']
 * @param {number} [opts.memUpdateMs=100]  turbo86 framebuffer stream cadence
 * @param {(s:object)=>void} [opts.onStatus]
 * @param {(engine:string, info?:string)=>void} [opts.onEngine]
 * @param {(ev:{code:number, name:string, engine:string})=>void} [opts.onInput]
 *        Fired for each accepted keypress (after the hover gate), so the
 *        page can log that input was received and where it went.
 */
export async function runDeck(canvas, deckUrl, opts = {}) {
    const res = await fetch(deckUrl);
    if (!res.ok) throw new Error(`fetch ${deckUrl}: ${res.status}`);
    const bytes = new Uint8Array(await res.arrayBuffer());
    const vm = await loadVm(bytes);

    const ctx = canvas.getContext('2d');
    const batch = BigInt(opts.batch ?? 2_000_000);
    const turbo86Url = opts.turbo86Url ?? 'ws://127.0.0.1:1234';
    const memUpdateMs = opts.memUpdateMs ?? 100;

    let engine = 'local';   // 'local' (movie86 wasm) | 'turbo86' (native)
    let ws = null;
    let nativeInsns = 0n;    // turbo86's retired-instruction count (MemUpdate)
    let imageData = null;
    let curMode = -1;
    let raf = 0;

    // Keyboard → the live engine: turbo86 over the WS as proto.KeyInput
    // while boosted, otherwise the local Vm's input queue. Reads `engine`/
    // `ws` live so the same handler follows the boost flip without
    // re-attaching. Gated to hover over the whole slide *area* (the
    // canvas's parent pane), not just the canvas: object-fit letterboxes
    // the canvas, so a pointer over the margin should still drive slides.
    // Off-area keystrokes stay with the page.
    const hoverEl = opts.hoverEl ?? canvas.parentElement ?? canvas;
    const detach = attachKeyboard((code) => {
        if (engine === 'turbo86' && ws && ws.readyState === WebSocket.OPEN) {
            ws.send(makeKeyInputMessage(code));
        } else {
            vm.pushInput(code);
        }
        opts.onInput?.({ code, name: keyName(code), engine });
    }, hoverEl);

    // Render the active mode's framebuffer. Reads from the local Vm for
    // both engines — turbo86's MemUpdate is written back into it.
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
        // Only the local engine steps the Vm; under boost the Vm is a
        // passive display buffer fed by turbo86's MemUpdate frames.
        if (engine === 'local' && !vm.haltReason) vm.stepN(batch);
        render();
        const m = modeForNumber(vm.activeVideoMode);
        opts.onStatus?.({
            engine,
            steps: engine === 'turbo86' ? nativeInsns : vm.steps,
            mode: vm.activeVideoMode,
            width: m?.width,
            height: m?.height,
            halt: vm.haltReason,
        });
        raf = requestAnimationFrame(frame);
    }
    raf = requestAnimationFrame(frame);

    function boost(url = turbo86Url) {
        if (engine === 'turbo86') return;
        let snap;
        try {
            snap = snapshotContext(vm);
        } catch (e) {
            opts.onEngine?.('local', `snapshot failed: ${e.message || e}`);
            return;
        }
        opts.onEngine?.('local', `connecting ${url}…`);
        try {
            ws = new WebSocket(url);
        } catch (e) {
            opts.onEngine?.('local', `bad URL: ${e.message || e}`);
            ws = null;
            return;
        }
        ws.onopen = () => {
            // Ask turbo86 to stream the framebuffer back so the canvas
            // keeps updating at native speed.
            ws.send(makeLoadContextMessage(snap, 'host', memUpdateMs));
            engine = 'turbo86';
            opts.onEngine?.('turbo86');
        };
        ws.onmessage = (e) => {
            let msg;
            try {
                msg = parseOutboundMessage(e.data);
            } catch {
                return;
            }
            switch (msg.type) {
                case 'video_mode':
                    // Mirror the guest's set_video_mode so render() picks
                    // the right framebuffer region (+ updates the badge).
                    vm.setActiveVideoMode(msg.mode & 0xff);
                    break;
                case 'mem_update':
                    for (const r of msg.regions) vm.writeMem(r.addr, r.bytes);
                    if (msg.insns) nativeInsns = BigInt(msg.insns);
                    break;
                case 'paused':
                    for (const r of msg.regions) vm.writeMem(r.addr, r.bytes);
                    break;
                case 'fault':
                    opts.onEngine?.('turbo86', `turbo86 fault: ${msg.reason}`);
                    break;
                case 'exit':
                    opts.onEngine?.('turbo86', `turbo86 exit ${msg.code}`);
                    break;
                default:
                    break;
            }
        };
        ws.onerror = () => {
            opts.onEngine?.(engine, 'turbo86 connection error (is it running?)');
        };
        ws.onclose = () => {
            ws = null;
            engine = 'local';
            opts.onEngine?.('local', 'turbo86 disconnected — back on movie86');
        };
    }

    return {
        vm,
        engine: () => engine,
        boost,
        stop() {
            cancelAnimationFrame(raf);
            detach();
            if (ws) { try { ws.close(); } catch { /* ignore */ } }
            vm.free();
        },
    };
}
