// explorer.mjs — unified compile API for the x86.mov Explorer page.
//
// Wraps movfuscator-wasm and llvm-mov-wasm behind a single shape so
// the UI doesn't have to thread two import sites with two argument
// schemas. Each call returns a normalized result the UI renders the
// same way regardless of which compiler ran:
//
//   { compiler, ir, asm, obj, elf, timings }
//
// `ir` is null for movfuscator (LCC's tree IR isn't surfaced as a
// textual product; the only inspectable intermediate is the `.s` itself).
// The UI hides the IR pane when `ir` is null.
//
// movfuscator pipeline: source → compile() → assemble() → link()
// llvm-mov   pipeline: source → cToIR() → compile(ir) → assemble() → link()
//
// Both pipelines reuse movfuscator-wasm's `assemble` + `link` for the
// `.s → .o → ELF` tail — they're byte-identical with host `as` / `ld`
// on shared inputs, and we don't want to ship a second copy of the
// binutils-as-wasm artefacts under `llvm-mov/wasm/`. The relative
// import lands at `../movfuscator-wasm/movfuscator.mjs` whether the
// page is served from `make serve` or the deployed
// `dist/explorer/index.html` (sibling subprojects).
//
// Tests dependency-inject the wrappers via `opts.wrappers` so the unit
// suite can exercise the orchestration without paying the ~80 MB
// clang.wasm load. Production calls leave `wrappers` undefined and the
// default lazy import resolves to the real wasm modules.

export const COMPILERS = Object.freeze(['movfuscator', 'llvm-mov']);

// llvm-mov-llc refuses anything but `mov-*` triples — clang stamps
// `i386-unknown-linux-gnu` into the IR, so the IR → asm step must
// force the override every time. Same default the llvm-mov/wasm tests
// and demo use.
const MOV_TRIPLE = 'mov-unknown-linux-gnu';

/**
 * Compile C source through the selected mov-only toolchain.
 *
 * @param {object} params
 * @param {'movfuscator'|'llvm-mov'} params.compiler
 * @param {string} params.source — C source text
 * @param {object} [params.opts]
 * @param {string} [params.opts.optLevel='0'] — clang -O level
 *   (llvm-mov only; movfuscator/LCC has no equivalent knob)
 * @param {string[]} [params.opts.clangFlags] — extra clang flags
 *   (llvm-mov only)
 * @param {Record<string,string>} [params.opts.headers] — name → text,
 *   mounted in MEMFS root so source can `#include "name.h"`
 *   (movfuscator only — clang already embeds the resource-dir headers)
 * @param {object} [params.opts.linkOpts] — forwarded to
 *   `movfuscator.link()` (extraLibs / searchPaths / extraInputs)
 * @param {(stage: string) => void} [params.opts.onProgress]
 * @param {object} [params.wrappers] — dependency injection for tests
 * @returns {Promise<{
 *   compiler: string,
 *   ir: string|null,
 *   asm: string,
 *   obj: Uint8Array,
 *   elf: Uint8Array,
 *   timings: Record<string, number>,
 * }>}
 */
export async function compileWithCompiler(params) {
    const { compiler, source, opts = {}, wrappers } = params;
    if (!COMPILERS.includes(compiler)) {
        throw new Error(`unknown compiler: ${compiler} (want one of: ${COMPILERS.join(', ')})`);
    }
    if (!wrappers) {
        // Callers must inject the loaded wasm wrappers — this module
        // is framework-free and intentionally has no static imports
        // of the sibling subprojects (they reference build-time
        // chunks that wouldn't survive Vite/Rollup's resolver). The
        // React app provides them via `lib/wrappers.ts`'s lazy
        // loaders; the unit suite provides fakes.
        throw new Error('compileWithCompiler: opts.wrappers is required (call site must inject loaded wasm modules)');
    }
    const w = wrappers;
    const onProgress = opts.onProgress ?? (() => {});
    const timings = {};
    const t0 = performance.now();

    let ir = null;
    let asm;

    if (compiler === 'movfuscator') {
        onProgress('compile-c');
        const t1 = performance.now();
        asm = await w.movfuscator.compile(source, opts.headers ?? {});
        timings.compile = performance.now() - t1;
    } else {
        // llvm-mov: C → IR → asm in two wasm calls, with the IR
        // surfaced for the UI's middle pane.
        onProgress('compile-c');
        const t1 = performance.now();
        ir = await w.llvmMov.cToIR(source, {
            optLevel: opts.optLevel ?? '0',
            clangFlags: opts.clangFlags ?? [],
        });
        timings.cToIR = performance.now() - t1;

        onProgress('compile-ir');
        const t2 = performance.now();
        asm = await w.llvmMov.compile(ir, { mtriple: MOV_TRIPLE });
        timings.irToAsm = performance.now() - t2;
    }

    onProgress('assemble');
    const ta = performance.now();
    const obj = await w.movfuscator.assemble(asm);
    timings.assemble = performance.now() - ta;

    onProgress('link');
    const tl = performance.now();
    const elf = await w.movfuscator.link(obj, undefined, {
        name: 'explorer.o',
        ...(opts.linkOpts ?? {}),
    });
    timings.link = performance.now() - tl;

    timings.total = performance.now() - t0;
    return { compiler, ir, asm, obj, elf, timings };
}
