// Thin ergonomic wrapper around the wasm-bindgen ESM module.
//
// The shape mirrors movfuscator-wasm/movfuscator.mjs: a single
// auto-initialising helper (`runElf`) that lazily loads the wasm once
// per page and returns a plain JS object — callers don't deal with
// `init()` themselves.

import init, { runElf as runElfRaw, Vm as VmRaw } from './build/browser/movie86_wasm.js';

/**
 * Memory-mapped framebuffer modes — loosely styled after real-mode
 * VGA.
 *
 * Each entry is a "graphics mode" with a fixed (width, height) and a
 * dedicated guest address. The guest draws by `mov`-ing 4-byte RGBA
 * pixels into the slot it wants to use; the host polls every slot
 * each render and `putImageData`s the bytes onto the matching
 * `<canvas>`. No new syscall / no new interrupt is involved — the
 * only thing the guest needs is a writable PT_LOAD segment that
 * covers `[addr, addr + width * height * 4)`. ELFs that don't write
 * to a slot leave that canvas blank.
 *
 * The address layout deliberately echoes real x86:
 *
 *   - `mode 13h`  → 320×200 at **0xA0000** (the classic VGA window
 *     start; in real mode 13h this held a 1-byte-per-pixel paletted
 *     image, here it's straight RGBA — close in spirit, not in
 *     encoding)
 *   - `mode 12h`  → 640×480 at **0x100000** (the standard VGA "high
 *     res" mode; we park it above the 1 MB boundary because real
 *     mode 12h is planar 4bpp and the RGBA-flat equivalent doesn't
 *     fit in the 64 KB window at A0000)
 *
 * Both are deliberately "famous" resolutions — `64x64`-style square
 * sizes don't show up in real PC history and felt arbitrary; mode 13h
 * is the iconic demoscene canvas and 640×480 is the lowest-common
 * VGA "real" resolution.
 */
export const FRAMEBUFFER_MODES = Object.freeze([
    { id: 'mode 13h', addr: 0x000A_0000, width: 320, height: 200 }, // 250 KB
    { id: 'mode 12h', addr: 0x0010_0000, width: 640, height: 480 }, // 1.2 MB
].map(m => Object.freeze({
    ...m,
    bytesPerPixel: 4,
    byteLength: m.width * m.height * 4,
})));

let initialized = null;

async function ensureInit() {
    if (!initialized) {
        // wasm-bindgen --target web wants either a fetch URL or
        // ArrayBuffer for the wasm; the default (no arg) does
        // `fetch(new URL('./<name>_bg.wasm', import.meta.url))`, which
        // works under static hosts.
        initialized = init();
    }
    return initialized;
}

/**
 * Run an ELF32 i386 executable through the movie86 emulator.
 *
 * @param {Uint8Array} bytes  The ELF binary.
 * @param {object} [opts]
 * @param {number|bigint} [opts.maxSteps]  Instruction budget. Default
 *     50_000_000 — the emulator otherwise runs unbounded on movfuscator
 *     binaries' master_loop and hangs the tab.
 * @returns {Promise<{
 *     stdout: string,
 *     stderr: string,
 *     stdoutBytes: Uint8Array,
 *     stderrBytes: Uint8Array,
 *     exitCode: number,
 *     fault: string|null,
 *     steps: bigint,
 * }>}
 */
export async function runElf(bytes, opts = {}) {
    await ensureInit();
    // wasm-bindgen surfaces u64 as BigInt; accept a plain number too.
    const maxSteps =
        opts.maxSteps == null
            ? undefined
            : typeof opts.maxSteps === 'bigint'
              ? opts.maxSteps
              : BigInt(opts.maxSteps);
    const r = runElfRaw(bytes, maxSteps);
    try {
        return {
            stdout: r.stdout,
            stderr: r.stderr,
            stdoutBytes: r.stdoutBytes,
            stderrBytes: r.stderrBytes,
            exitCode: r.exitCode,
            fault: r.fault ?? null,
            steps: r.steps,
        };
    } finally {
        // wasm-bindgen-allocated objects don't get GC'd until free()
        // is called. Long-running pages would leak the result struct
        // (it's tiny, but principle).
        r.free();
    }
}

/**
 * Construct a step-driven [`Vm`] handle. The returned object is the
 * wasm-bindgen wrapper directly — see the Rust-side docs in
 * `src/lib.rs` for method semantics.
 *
 * Caller is responsible for `vm.free()` when done.
 *
 * @param {Uint8Array} bytes  ELF32 i386 binary.
 */
export async function loadVm(bytes) {
    await ensureInit();
    return new VmRaw(bytes);
}
