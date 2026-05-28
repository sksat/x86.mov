// llvm-mov-wasm: Node ESM / browser wrapper around clang.wasm +
// llvm-mov-llc.wasm.
//
// Usage (Node, after `make build`):
//   import { compileC, compile } from './llvm-mov.mjs';
//   const asm = await compileC('int main(void){ return 42; }');
//   // …or skip the C frontend and feed LLVM IR directly:
//   const asm2 = await compile('target triple="mov-..."\n…');
//
// The `.s → .o → ELF` tail of the pipeline lives in ../movfuscator-wasm
// (its `assemble` and `link` are byte-identical with host as/ld on the
// shared inputs).
//
// Each call instantiates a fresh module — the underlying drivers call
// exit() at the end of main (EXIT_RUNTIME=1), making the runtime
// non-reusable. Same shape as movfuscator-wasm's wrappers.

import createMovLlc from './build/llvm-mov-llc.js';

// Clang is lazy-loaded so callers who only need `.ll → .s` (i.e. the
// `compile()` API) can run without the 80 MB clang.wasm artifact
// present. The dynamic import is cached by the host module loader.
let _createMovClang = null;
async function loadClang() {
    if (_createMovClang === null) {
        const m = await import('./build/clang.js');
        _createMovClang = m.default;
    }
    return _createMovClang;
}

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
 * @param {{ name?: string, mtriple?: string }} [opts]
 *   - `name`: basename used for the MEMFS input file. The native driver
 *     bakes the input filename into a `.file "<name>"` directive, so
 *     matching it here is required for byte-identical parity with
 *     native `llvm-mov-llc`. Defaults to `in.ll`.
 *   - `mtriple`: forwarded as `-mtriple=<value>` to llvm-mov-llc to
 *     override the triple baked into the IR. Required when feeding
 *     clang-emitted IR (which carries `i386-unknown-linux-gnu` from
 *     `-target i386-...`) — the driver only accepts a `mov-...` triple
 *     unless one is explicitly forced.
 * @returns {Promise<string>} mov-target x86-32 GAS-syntax assembly text
 */
export async function compile(ir, opts = {}) {
    if (typeof ir !== 'string') {
        throw new TypeError('ir must be a string');
    }
    const { name = 'in.ll', mtriple } = opts;
    assertSafeName(name);
    const args = [`/${name}`, '-o', '/out.s'];
    if (mtriple !== undefined) {
        if (typeof mtriple !== 'string' || mtriple.length === 0) {
            throw new TypeError('opts.mtriple must be a non-empty string');
        }
        args.unshift(`-mtriple=${mtriple}`);
    }
    const buf = makeBuffered();
    const llc = await createMovLlc(buf.opts);
    llc.FS.writeFile(`/${name}`, ir);
    const exit = llc.callMain(args);
    if (exit !== 0) {
        throw new Error(`llvm-mov-llc exited ${exit}\n${buf.joined()}`);
    }
    return llc.FS.readFile('/out.s', { encoding: 'utf8' });
}

// Optimization levels passed through to clang. `-O0` is special:
// clang adds an `optnone` attribute to every function at -O0, which
// disables every IR pass in llvm-mov-llc and breaks the mov-only
// legalize stages on anything non-trivial. We tag `-Xclang
// -disable-O0-optnone` onto -O0 so the IR retains the shape llc
// expects. At -O1+ clang already runs its IR pipeline before
// emit-llvm, no special-casing needed.
const VALID_OPT_LEVELS = new Set(['0', '1', '2', '3', 's', 'z']);
function flagsForOptLevel(level) {
    if (typeof level !== 'string' || !VALID_OPT_LEVELS.has(level)) {
        throw new Error(
            `invalid optLevel ${JSON.stringify(level)}; expected one of ${[...VALID_OPT_LEVELS].join(', ')}`,
        );
    }
    const out = [`-O${level}`];
    if (level === '0') out.push('-Xclang', '-disable-O0-optnone');
    return out;
}

// Base flags passed to clang for the C-frontend step (everything except
// the opt level).
// - `-S -emit-llvm`: stop after LLVM IR generation (don't try to assemble).
// - `-target i386-unknown-linux-gnu`: ABI/data-layout target for the
//   IR. llvm-mov-llc retargets it to `mov-...` via `-mtriple` so the
//   user never has to touch a triple.
// - `-fno-stack-protector -fno-builtin -fno-pic`: keep the IR free of
//   runtime-library shapes the downstream pipeline can't link against
//   (no libc, no PIC GOT).
// - `-fno-ident`: drop the `!llvm.ident` metadata clang otherwise
//   embeds. Its payload is the build's distribution string (e.g.
//   "Debian clang 22.1.6 (...)") which differs between the system
//   clang we use as the parity reference and the wasm clang we build
//   from vendor/llvm-project/. Without this flag the IR and the
//   downstream `.ident` asm directive carry that string and the
//   byte-identical parity test fails for cosmetic reasons.
// - `-nostdinc -nostdlibinc`: the wasm clang only ships its own
//   resource-dir headers (no glibc); blocking the search prevents the
//   driver from looking for system headers that aren't there.
const CLANG_BASE_FLAGS = [
    '-S', '-emit-llvm',
    '-target', 'i386-unknown-linux-gnu',
    // Pin the target-CPU so the IR's `target-cpu` / `target-features`
    // attributes don't drift between the system clang (Debian's i686
    // default) and the vendored upstream clang (pentium4 default).
    // i386 is the lowest baseline; the mov-only legalize stages don't
    // use any extension features anyway.
    '-march=i386',
    '-fno-stack-protector',
    '-fno-builtin',
    '-fno-pic',
    '-fno-ident',
    '-nostdinc', '-nostdlibinc',
];

/**
 * Compile C source text to LLVM IR (.ll text) via clang.wasm.
 * Useful on its own for inspecting the intermediate IR, or chain into
 * `compile()` for the full C → mov-target asm path.
 * @param {string} source C source code.
 * @param {{ name?: string, optLevel?: string, clangFlags?: string[] }} [opts]
 *   - `name`: MEMFS basename of the input file. Defaults to `in.c`.
 *     The basename leaks into the IR's `source_filename` directive, so
 *     parity tests should pass the same basename to both this wrapper
 *     and the native clang they diff against.
 *   - `optLevel`: clang `-O<level>`. One of '0', '1', '2', '3', 's', 'z'.
 *     Defaults to '0'.
 *   - `clangFlags`: extra flags appended to the default set (e.g.
 *     additional `-D` / `-I`).
 * @returns {Promise<string>} LLVM IR text
 */
export async function cToIR(source, opts = {}) {
    if (typeof source !== 'string') {
        throw new TypeError('source must be a string');
    }
    const { name = 'in.c', optLevel = '0', clangFlags = [] } = opts;
    assertSafeName(name);
    if (!Array.isArray(clangFlags) || !clangFlags.every(f => typeof f === 'string')) {
        throw new TypeError('opts.clangFlags must be a string[]');
    }
    const optFlags = flagsForOptLevel(optLevel);
    const createMovClang = await loadClang();
    const buf = makeBuffered();
    const clang = await createMovClang(buf.opts);
    // Stage the file at MEMFS / and pass clang the *bare basename* (not
    // /<name>). Emscripten starts the wasm module with cwd = /, so a
    // bare basename resolves correctly, and the IR's `source_filename`
    // line ends up matching what a native `cd $dir && clang in.c`
    // invocation produces — important for byte-identical parity.
    clang.FS.writeFile(`/${name}`, source);
    const llName = name.replace(/\.c$/, '') + '.ll';
    const exit = clang.callMain([
        ...CLANG_BASE_FLAGS, ...optFlags, ...clangFlags,
        name, '-o', llName,
    ]);
    if (exit !== 0) {
        throw new Error(`clang exited ${exit}\n${buf.joined()}`);
    }
    return clang.FS.readFile(`/${llName}`, { encoding: 'utf8' });
}

/**
 * Compile a C source string to mov-target x86-32 assembly (.s text)
 * through clang + llvm-mov-llc.
 * @param {string} source C source code.
 * @param {{ name?: string, optLevel?: string, clangFlags?: string[] }} [opts]
 *   - Forwarded to `cToIR` (basename, opt level, extra clang flags).
 * @returns {Promise<string>} mov-target x86-32 GAS-syntax assembly text
 */
export async function compileC(source, opts = {}) {
    const ir = await cToIR(source, opts);
    // llvm-mov-llc bakes the input basename into the `.file "..."`
    // directive. Use the same `<stem>.ll` MEMFS basename here that
    // cToIR used, so the parity test sees identical asm between the
    // two-step (cToIR + compile) and one-step (compileC) callers.
    //
    // clang's IR carries `target triple = "i386-unknown-linux-gnu"`
    // (from the `-target i386-...` we hand it). llvm-mov-llc refuses
    // anything that isn't a `mov-...` triple unless `-mtriple` overrides
    // it, so we force-retarget here to the Mov default.
    const llName = (opts.name ?? 'in.c').replace(/\.c$/, '') + '.ll';
    return compile(ir, { name: llName, mtriple: 'mov-unknown-linux-gnu' });
}
