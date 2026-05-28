// Thin ergonomic wrapper around the wasm-bindgen ESM module.
//
// The shape mirrors movfuscator-wasm/movfuscator.mjs: a single
// auto-initialising helper (`runElf`) that lazily loads the wasm once
// per page and returns a plain JS object — callers don't deal with
// `init()` themselves.

import init, { runElf as runElfRaw, Vm as VmRaw } from './build/browser/movie86_wasm.js';

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
