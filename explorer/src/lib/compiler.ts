// TS facade in front of `../../explorer.mjs` — the framework-free
// orchestration layer that's also covered by `tests/unit.test.mjs`.
// Keep this file thin: cross-PR refactors and the no-React unit suite
// both work against the .mjs module, so the React app should reuse it
// without forking the algorithm.

import { compileWithCompiler as _compile, COMPILERS as _COMPILERS } from '../../explorer.mjs';
import { loadLlvmMov, loadMovfuscator } from './wrappers';

export type CompilerId = 'movfuscator' | 'llvm-mov';
export const COMPILERS = _COMPILERS as readonly CompilerId[];

export type OptLevel = '0' | '1' | '2' | '3' | 's' | 'z';

export interface CompileParams {
    compiler: CompilerId;
    source: string;
    opts?: {
        optLevel?: OptLevel;
        clangFlags?: string[];
        headers?: Record<string, string>;
        linkOpts?: {
            name?: string;
            /** Link statically (drops `-dynamic-linker`, adds `-static`).
             *  movie86 needs this; the explorer's llvm-mov path defaults to
             *  `true` in explorer.mjs. movfuscator stays dynamic until the
             *  movie86 master_loop dispatch-table fault is resolved. */
            static?: boolean;
            /** Which CRT objects the wrapper auto-wraps the inputs in.
             *  `'none'` = caller supplies `_start.o` (llvm-mov default). */
            runtime?: 'movfuscator' | 'none';
            extraLibs?: string[];
            searchPaths?: string[];
            extraInputs?: Record<string, Uint8Array>;
            /** Raw `ld` flags spliced in verbatim (one slot per entry).
             *  The canvas13h link profile uses this for
             *  `--section-start` / `--undefined`; callers rarely set it
             *  directly. */
            extraLdArgs?: string[];
        };
        /** Named link recipe (llvm-mov path only). `'canvas13h'` links
         *  the mov-only ABI framebuffer stubs + pins `.fb13h` at the VGA
         *  base so a mode-13h program renders in the Canvas pane. Driven
         *  by the selected preset's `linkProfile`. */
        linkProfile?: 'canvas13h';
        onProgress?: (stage: string) => void;
    };
}

export interface CompileResult {
    compiler: CompilerId;
    /** llvm-mov path only; null for movfuscator. */
    ir: string | null;
    asm: string;
    obj: Uint8Array;
    elf: Uint8Array;
    timings: Record<string, number>;
}

/** Run the full source → ELF pipeline. The wrappers are loaded lazily
 *  the first time each compiler runs; subsequent calls reuse the same
 *  module handle so clang.wasm + the binutils-as/ld wasm stay warm. */
export async function compile(params: CompileParams): Promise<CompileResult> {
    // movfuscator's `assemble` + `link` are always in the chain (we
    // share the binutils-wasm tail for both compilers), so preload it
    // alongside the per-compiler frontend so the two fetches
    // parallelise.
    const wrappers = await loadWrappers(params.compiler);
    return (await _compile({ ...params, wrappers })) as CompileResult;
}

async function loadWrappers(compiler: CompilerId) {
    if (compiler === 'movfuscator') {
        const movfuscator = await loadMovfuscator();
        return { movfuscator };
    }
    const [movfuscator, llvmMov] = await Promise.all([
        loadMovfuscator(),
        loadLlvmMov(),
    ]);
    return { movfuscator, llvmMov };
}
