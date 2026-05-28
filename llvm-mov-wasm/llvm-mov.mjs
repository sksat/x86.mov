// llvm-mov-wasm: Node ESM / browser wrapper around llvm-mov-llc.wasm.
//
// Usage (Node, after `make build`):
//   import { compile } from './llvm-mov.mjs';
//   const asm = await compile(`
//     target triple = "mov-unknown-linux-gnu"
//     define i32 @main() { ret i32 42 }
//   `);
//
// The `.s → .o → ELF` tail of the pipeline lives in ../movfuscator-wasm
// (its `assemble` and `link` are byte-identical with host as/ld on the
// shared inputs).
//
// Each call instantiates a fresh module — the underlying driver calls
// exit() at the end of main (EXIT_RUNTIME=1), making the runtime
// non-reusable. Same shape as movfuscator-wasm's wrappers.

import createMovLlc from './build/llvm-mov-llc.js';

// llvm-mov-llc writes its banner ("input module data layout mismatch"
// would-be-warning, the InitLLVM signal handler banner, etc.) to stderr.
// Buffer it and only surface if exit != 0, mirroring movfuscator-wasm.
function makeBuffered() {
    const lines = [];
    return {
        opts: { print: () => {}, printErr: (s) => lines.push(s) },
        joined: () => lines.join('\n'),
    };
}

// Conservative basename guard for opts.name. The string ends up on the
// `.file` directive in the emitted assembly and in MEMFS, so anything
// containing path separators or traversal would break both layers.
function assertSafeName(name) {
    if (typeof name !== 'string' || name.length === 0) {
        throw new TypeError('opts.name must be a non-empty string');
    }
    if (name === '.' || name === '..'
        || name.includes('/') || name.includes('\\')) {
        throw new Error(`opts.name ${JSON.stringify(name)} must be a basename without path separators`);
    }
}

/**
 * Compile LLVM IR (.ll text) to mov-target x86-32 assembly (.s text).
 * @param {string} ir LLVM IR source text. If it lacks a
 *   `target triple = "..."` line, the driver defaults to
 *   `mov-unknown-linux-gnu`.
 * @param {{ name?: string }} [opts]
 *   - `name`: basename used for the MEMFS input file. The native driver
 *     bakes the input filename into a `.file "<name>"` directive, so
 *     matching it here is required for byte-identical parity with
 *     native `llvm-mov-llc`. Defaults to `in.ll`.
 * @returns {Promise<string>} mov-target x86-32 GAS-syntax assembly text
 */
export async function compile(ir, opts = {}) {
    if (typeof ir !== 'string') {
        throw new TypeError('ir must be a string');
    }
    const { name = 'in.ll' } = opts;
    assertSafeName(name);
    const buf = makeBuffered();
    const llc = await createMovLlc(buf.opts);
    llc.FS.writeFile(`/${name}`, ir);
    const exit = llc.callMain([`/${name}`, '-o', '/out.s']);
    if (exit !== 0) {
        throw new Error(`llvm-mov-llc exited ${exit}\n${buf.joined()}`);
    }
    return llc.FS.readFile('/out.s', { encoding: 'utf8' });
}
