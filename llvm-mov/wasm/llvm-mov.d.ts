/**
 * Status event emitted by `onProgress` callbacks. Stages:
 *  - `fetch-clang`: progress streaming the zstd-encoded
 *    clang.wasm-{version}.zst from the deploy. Throttled to ~20 Hz
 *    on the wire; an initial event with all zeros fires before the
 *    first byte lands. Only emitted when the deploy is in use
 *    (`CLANG_WASM_VERSION` non-null in `wasm-config.js`).
 *    - `bytes`: bytes received so far. Equal to wire bytes when the
 *      browser is decompressing zstd natively, otherwise compressed
 *      bytes that will get decompressed on the JS side after fetch.
 *    - `totalBytes`: server's `Content-Length` (0 until the response
 *      header lands).
 *  - `decompress-clang`: fzstd is about to run on the compressed
 *    bytes. Only fires on browsers without native `Content-Encoding:
 *    zstd` support.
 *  - `instantiate-clang` / `instantiate-llc`: the Emscripten module
 *    is about to be instantiated.
 *  - `compile-c`: clang's main() is about to run (C → LLVM IR).
 *  - `compile-ir`: llvm-mov-llc's main() is about to run (IR → asm).
 */
export type ProgressEvent =
    | { stage: 'fetch-clang'; bytes: number; totalBytes: number }
    | { stage: 'decompress-clang' }
    | { stage: 'instantiate-clang' }
    | { stage: 'instantiate-llc' }
    | { stage: 'compile-c' }
    | { stage: 'compile-ir' };

export type ProgressCallback = (ev: ProgressEvent) => void;

export interface CompileOptions {
    /**
     * Basename used for the MEMFS input file. The native driver bakes
     * the input filename into a `.file "<name>"` directive, so matching
     * it here is required for byte-identical parity with native
     * `llvm-mov-llc`. Defaults to `in.ll`.
     */
    name?: string;
    /**
     * Forwarded as `-mtriple=<value>` to llvm-mov-llc to override the
     * triple baked into the IR. Required when feeding clang-emitted IR
     * (which carries `i386-unknown-linux-gnu`); the driver only accepts
     * `mov-...` triples unless one is explicitly forced.
     */
    mtriple?: string;
    /** Status callback; see ProgressEvent for the stage sequence. */
    onProgress?: ProgressCallback;
}

export type OptLevel = '0' | '1' | '2' | '3' | 's' | 'z';

export interface CompileCOptions {
    /** Basename of the MEMFS input file fed to clang. Defaults to `in.c`. */
    name?: string;
    /** Clang optimization level. Defaults to `'0'`. */
    optLevel?: OptLevel;
    /** Extra clang command-line flags (e.g. `-D` / `-I`). */
    clangFlags?: string[];
    /** Status callback; see ProgressEvent for the stage sequence. */
    onProgress?: ProgressCallback;
}

/**
 * Compile LLVM IR (.ll text) to mov-target x86-32 assembly (.s text).
 * @param ir LLVM IR source text. If it lacks a `target triple = "..."`
 *   line, the driver defaults to `mov-unknown-linux-gnu`.
 * @returns mov-target x86-32 GAS-syntax assembly text
 */
export function compile(ir: string, opts?: CompileOptions): Promise<string>;

/**
 * Compile C source text to LLVM IR (.ll text) via clang.wasm. Useful
 * for inspecting the intermediate IR; chain into `compile()` for the
 * full C → mov-target asm path.
 */
export function cToIR(source: string, opts?: CompileCOptions): Promise<string>;

/**
 * Compile C source text to mov-target x86-32 assembly (.s text) through
 * clang + llvm-mov-llc, all in wasm. Equivalent to `compile(await
 * cToIR(source, opts))` with the basenames lined up.
 */
export function compileC(source: string, opts?: CompileCOptions): Promise<string>;
