// Thin ergonomic wrapper around the wasm-bindgen ESM module.
//
// The shape mirrors movfuscator-wasm/movfuscator.mjs: a single
// auto-initialising helper (`runElf`) that lazily loads the wasm once
// per page and returns a plain JS object — callers don't deal with
// `init()` themselves.

import init, {
    runElf as runElfRaw,
    Vm as VmRaw,
    ContextSnapshot as ContextSnapshotRaw,
} from './build/browser/movie86_wasm.js';

/**
 * Memory-mapped framebuffer modes — loosely styled after real-mode
 * VGA.
 *
 * Each entry is a "graphics mode" with a fixed (width, height), a
 * dedicated guest address, and a BIOS mode number (matches real x86
 * `int 0x10 ; AH=0 ; AL=mode`). The guest:
 *
 *   1. Sets the mode with `mov eax, 0x0000_00NN` (AH=0, AL=NN) +
 *      `int 0x10` — the host records the selection.
 *   2. Draws by `mov`-ing 4-byte RGBA pixels into that mode's address
 *      range. ELFs that don't write to a slot leave its canvas blank
 *      (BSS-zeroed).
 *
 * The demo only renders the **active** mode (whichever was last set
 * via `int 0x10`), so non-canvas examples don't clutter the UI with
 * empty canvases. Querying `vm.activeVideoMode` returns the mode
 * number set by the guest, or `undefined` if none was ever set.
 *
 * The address + mode-number layout echoes real x86 graphics history:
 *
 *   - `0x13` (mode 13h) → 320×200 — classic VGA, the demoscene 256-
 *     colour mode. In real mode 13h this was 1-byte-per-pixel paletted
 *     data; here it's straight RGBA. "Spirit of", not exact.
 *   - `0x12` (mode 12h) → 640×480 — standard VGA 16-colour planar in
 *     real life; RGBA-flat here.
 *   - `0x10` (mode 10h) → 640×350 — EGA/VGA mid-res. The "missing"
 *     resolution between mode 13h and mode 12h that anyone who
 *     remembers DOS asks about.
 *   - `0x6A` (VESA VBE 1.0) → 800×600 — the standardised SVGA step
 *     up. Not strictly VGA but the universally-supported next mode.
 *
 * Addresses are spaced so the loader's single flat region can fit
 * them all if an ELF declares more than one PT_LOAD: mode 13h sits
 * at the real-VGA window (0xA0000) and each subsequent mode is parked
 * past the end of the previous one, leaving room without overlap.
 *
 * Unofficial modes like "mode-X" (320×240 — square pixels, demoscene
 * favourite) aren't listed because they were set by direct VGA
 * register programming, not by a BIOS function number.
 *
 * `64×64`-style sizes don't show up in real PC history and felt
 * arbitrary, so the catalogue is deliberately limited to famous
 * VGA / VESA modes.
 */
export const FRAMEBUFFER_MODES = Object.freeze([
    { id: 'mode 13h', modeNumber: 0x13, addr: 0x000A_0000, width: 320, height: 200 }, //  250 KB — VGA 256c (the famous one)
    { id: 'mode 12h', modeNumber: 0x12, addr: 0x0010_0000, width: 640, height: 480 }, // 1.2 MB  — VGA 16c
    { id: 'mode 10h', modeNumber: 0x10, addr: 0x0030_0000, width: 640, height: 350 }, //  875 KB — EGA/VGA mid-res
    { id: 'VESA 6Ah', modeNumber: 0x6A, addr: 0x0040_0000, width: 800, height: 600 }, // 1.9 MB  — VESA VBE 1.0 SVGA
].map(m => Object.freeze({
    ...m,
    bytesPerPixel: 4,
    byteLength: m.width * m.height * 4,
})));

/** Look up a mode by its BIOS mode number (`vm.activeVideoMode`).
 *  Returns `undefined` if the guest set a mode the demo doesn't know. */
export function modeForNumber(n) {
    return FRAMEBUFFER_MODES.find(m => m.modeNumber === n);
}

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

/**
 * Plain-JS view of a Context snapshot. Shape mirrors the core crate's
 * `movie86::context::Context` and turbo86's `proto.Context`:
 *
 *     {
 *       regs: { eax, ebx, ecx, edx, esi, edi, ebp, esp, eip, eflags },
 *       regions: [ { addr: number, bytes: Uint8Array }, ... ]
 *     }
 *
 * Capture the live state of `vm` as such a snapshot. Frees the
 * underlying wasm-bindgen handle before returning so callers only deal
 * with plain JS values (no `.free()` to remember). Region byte arrays
 * are owned copies — safe to keep across subsequent `vm.stepN` calls.
 *
 * @param {Vm} vm
 * @returns {{regs: object, regions: Array<{addr: number, bytes: Uint8Array}>}}
 */
export function snapshotContext(vm) {
    const s = vm.snapshotContext();
    try {
        const regs = {
            eax: s.eax, ebx: s.ebx, ecx: s.ecx, edx: s.edx,
            esi: s.esi, edi: s.edi, ebp: s.ebp, esp: s.esp,
            eip: s.eip, eflags: s.eflags,
        };
        const regions = [];
        const n = s.regionCount;
        for (let i = 0; i < n; i++) {
            regions.push({
                addr: s.regionAddrAt(i),
                bytes: s.regionBytesAt(i),
            });
        }
        return { regs, regions };
    } finally {
        s.free();
    }
}

// Base64-encode a Uint8Array. Browsers and Node 16+ both expose
// `btoa`, but it takes a binary string, not a byte array — so we walk
// the bytes in 0x8000-byte chunks to avoid the "maximum call stack
// size" trap from `String.fromCharCode(...largeArray)`. For the
// snapshot payload sizes we care about (single MiB at the very high
// end), this is more than fast enough; a future optimization could
// drop down to a manual encoder if it ever shows up in a profile.
function bytesToBase64(u8) {
    const CHUNK = 0x8000;
    let s = '';
    for (let i = 0; i < u8.length; i += CHUNK) {
        s += String.fromCharCode.apply(null, u8.subarray(i, i + CHUNK));
    }
    return btoa(s);
}

function base64ToBytes(b64) {
    const bin = atob(b64);
    const out = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
}

/**
 * Build the turbo86 `LoadContext` Inbound frame for `ctx`. The result
 * is a JSON string ready to drop into `ws.send(...)`.
 *
 * Schema matches `turbo86/proto/proto.go`:
 *
 *     { "type": "load_context",
 *       "context": { "regs": {...}, "regions": [ { "addr", "bytes" }, ... ] },
 *       "mode": "host" | "trap" }
 *
 * `bytes` are emitted as base64 strings — Go's `encoding/json`
 * round-trips `[]byte` that way. The lowercase `type` discriminator
 * + lowercase field names are how the Go side spells them; any drift
 * would silently break the handshake.
 *
 * Mode defaults to `"host"` (turbo86 runs the kernel signal path —
 * matches the Go side's empty-string fallback). Pass `"trap"` when
 * the guest depends on the same software signal model movie86 uses
 * (movfuscator-style `mov cs, ax` → SIGILL dispatch).
 *
 * @param {{regs: object, regions: Array<{addr: number, bytes: Uint8Array}>}} ctx
 * @param {'host'|'trap'} [mode='host']
 * @returns {string} JSON-encoded frame, ready for WebSocket.send().
 */
export function makeLoadContextMessage(ctx, mode = 'host') {
    return JSON.stringify({
        type: 'load_context',
        context: {
            regs: ctx.regs,
            regions: ctx.regions.map(r => ({
                addr: r.addr,
                bytes: bytesToBase64(r.bytes),
            })),
        },
        mode,
    });
}

/**
 * Apply a plain-JS Context (the same shape `snapshotContext` returns,
 * or the `regs` + `regions` pair carried by a turbo86 `Paused`
 * Outbound) to `vm`. Restores regs + memory and clears the Vm's halt
 * state so subsequent `stepN` calls re-evaluate from the restored
 * EIP. The reverse of `snapshotContext` — the "Restore Vm from
 * turbo86 Paused" UI flow calls this.
 *
 * Returns `{ applied, skipped }`: how many regions landed inside the
 * Vm's mapped memory and how many had to be dropped (turbo86's stack
 * snapshot at 0x70000000+ doesn't fit in a movie86 FlatMemory sized
 * for a small ELF). The UI surfaces `skipped` so the user knows
 * stack-resident bits of the snapshot were lost; for movfuscator-
 * style programs whose hot state is code+regs, that's typically
 * sufficient.
 *
 * @param {Vm} vm
 * @param {{regs: object, regions: Array<{addr: number, bytes: Uint8Array}>}} ctx
 * @returns {{applied: number, skipped: number}}
 */
export function loadContextInto(vm, ctx) {
    const snap = new ContextSnapshotRaw();
    try {
        const r = ctx.regs;
        snap.setRegs(
            r.eax >>> 0, r.ebx >>> 0, r.ecx >>> 0, r.edx >>> 0,
            r.esi >>> 0, r.edi >>> 0, r.ebp >>> 0, r.esp >>> 0,
            r.eip >>> 0, (r.eflags ?? 0) >>> 0,
        );
        for (const region of ctx.regions) {
            // wasm-bindgen Vec<u8> takes a Uint8Array; copy if the
            // caller handed us something other (e.g. Buffer in Node).
            const bytes = region.bytes instanceof Uint8Array
                ? region.bytes
                : new Uint8Array(region.bytes);
            snap.addRegion(region.addr >>> 0, bytes);
        }
        const summary = vm.loadContext(snap);
        try {
            return { applied: summary.applied, skipped: summary.skipped };
        } finally {
            summary.free();
        }
    } finally {
        snap.free();
    }
}

/**
 * Decode a turbo86 Outbound frame. Returns a tagged JS object:
 *
 *   { type: 'stdout', bytes: Uint8Array }
 *   { type: 'stderr', bytes: Uint8Array }
 *   { type: 'exit',   code:  number }
 *   { type: 'fault',  reason: string }
 *   { type: 'paused', regs, regions, signal, reason }
 *
 * `bytes` fields are decoded from base64 back into `Uint8Array`. The
 * UI can treat them the same way it treats `vm.drainStdout()` output.
 * Unknown discriminators throw — the WS code is paired with a turbo86
 * head, not a forward-compat reader.
 *
 * @param {string|Uint8Array} data  WS frame body.
 */
export function parseOutboundMessage(data) {
    const text = typeof data === 'string' ? data : new TextDecoder().decode(data);
    const m = JSON.parse(text);
    switch (m.type) {
        case 'stdout': return { type: 'stdout', bytes: base64ToBytes(m.bytes) };
        case 'stderr': return { type: 'stderr', bytes: base64ToBytes(m.bytes) };
        case 'exit':   return { type: 'exit',   code: m.code };
        case 'fault':  return { type: 'fault',  reason: m.reason };
        case 'paused': {
            const regions = (m.regions ?? []).map(r => ({
                addr: r.addr,
                bytes: base64ToBytes(r.bytes),
            }));
            return { type: 'paused', regs: m.regs, regions, signal: m.signal, reason: m.reason };
        }
        default:
            throw new Error(`unknown turbo86 outbound type ${JSON.stringify(m.type)}`);
    }
}
