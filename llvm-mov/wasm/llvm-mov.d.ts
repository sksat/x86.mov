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
    | { stage: 'compile-ir' }
    // Rust-frontend (rsToIR) stages. Fire in order on a cold cache;
    // a warm cache skips `fetch-rustc` / `fetch-sysroot` (the marker
    // files in build/rustc-cache/<versionKey>/ short-circuit them).
    | { stage: 'fetch-rustc' }
    | { stage: 'fetch-sysroot' }
    | { stage: 'run-rustc' }
    // Host-rustc bypass (rsHostToIR) stage.
    | { stage: 'run-host-rustc' };

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

/**
 * One row of the rustc registry. See `RUSTC_VERSIONS`. Adding a new
 * Rust version means adding one entry here; no wrapper / test changes.
 */
export interface RustcVersionSpec {
    /** Rust version this artefact reports at startup (e.g. `1.83.0-dev`). */
    rustVersion: string;
    /** Editions accepted by this rustc. */
    editions: ReadonlyArray<'2015' | '2018' | '2021' | '2024'>;
    /** Triples this artefact ships sysroots for. */
    supportedTargets: ReadonlyArray<string>;
    /**
     * Artefact source. Two shapes:
     *  - Remote (`local` absent / false): driver fetches `rustcWasm`
     *    and `${sysrootBase}/${triple}.tar.br`, decompresses per
     *    `compression`, and populates the cache.
     *  - Local (`local: true`): driver skips fetch; the cache must
     *    already be populated by an out-of-band step (currently
     *    `scripts/build-wasm-rustc.sh`). The other fields are
     *    documentary only — `rustcWasm` typically uses a `local:`
     *    sentinel URL to make the layout self-explanatory.
     */
    artefacts: {
        local?: boolean;
        rustcWasm: string;
        /** Per-target sysroot lives at `${sysrootBase}/${triple}.tar.br`. */
        sysrootBase: string;
        compression: 'brotli' | 'none';
    };
    /**
     * Parity-test hint: which `rustup` channel matches this artefact's
     * Rust version closely enough for native-vs-wasm diff to be useful.
     */
    nativeRustup: string;
}

/** Default rustcVersion when `rsToIR` is called without one. */
export const DEFAULT_RUSTC_VERSION: string;

/**
 * Catalogue of selectable rustc.wasm artefacts. The single source of
 * truth for "which Rust versions does this wrapper know about?". Keys
 * are the values consumers pass as `opts.rustcVersion` to `rsToIR`.
 */
export const RUSTC_VERSIONS: Readonly<Record<string, RustcVersionSpec>>;

export interface RsToIROptions {
    /** Basename of the MEMFS input file. Defaults to `main.rs`. */
    name?: string;
    /** Key into `RUSTC_VERSIONS`. Defaults to `DEFAULT_RUSTC_VERSION`. */
    rustcVersion?: string;
    /** Must be in the chosen version's `supportedTargets`. */
    target?: string;
    /** Must be in the chosen version's `editions`. Defaults to `2021`. */
    edition?: '2015' | '2018' | '2021' | '2024';
    /** Forwarded as `-C opt-level=…`. */
    optLevel?: OptLevel;
    /**
     * Override the chosen version's default artefact URLs. Use this
     * to pin a self-hosted mirror without editing the registry.
     */
    artefacts?: {
        rustcWasm?: string;
        sysrootBase?: string;
    };
    /** Status callback; see ProgressEvent for the stage sequence. */
    onProgress?: ProgressCallback;
}

/**
 * Compile a single Rust source file to LLVM IR text via a wasm-hosted
 * rustc. Drives the artefact pointed at by `RUSTC_VERSIONS[opts.rustcVersion]`
 * through the `wasmtime` CLI (Node mode).
 *
 * Returns rustc's `--emit=llvm-ir` output. To feed the IR into the mov
 * backend (`compile()`), the artefact's target / data layout must
 * match what `llvm-mov-llc` accepts (currently `mov-...` / i386 ABI);
 * `wasm32-wasip1` output won't lower without an i686 sysroot artefact.
 */
export function rsToIR(source: string, opts?: RsToIROptions): Promise<string>;

export interface RsHostToIROptions {
    /** Basename for the source file written to a tempdir. Defaults to `in.rs`. */
    name?: string;
    /** Explicit rustc binary. Falls back to `$RUSTC` then `rustc` on PATH. */
    rustc?: string;
    /**
     * `--target`. Defaults to `i686-unknown-linux-gnu` — the one
     * `llvm-mov-llc` accepts (with an `mtriple` override). Requires
     * `rustup target add <target>` on the host.
     */
    target?: string;
    /** `--edition`. Defaults to `2024`. */
    edition?: '2015' | '2018' | '2021' | '2024';
    /** `--crate-type`. Defaults to `lib`. */
    crateType?: 'lib' | 'staticlib' | 'cdylib' | 'rlib';
    /** `-C opt-level=…`. Defaults to `'2'`. */
    optLevel?: OptLevel;
    /** Appended verbatim to the rustc command line. */
    rustcFlags?: string[];
    /** Status callback; see ProgressEvent for the stage sequence. */
    onProgress?: ProgressCallback;
}

/**
 * Compile a single Rust source file to LLVM IR text via the host
 * `rustc`. Node-only — spawns a subprocess. Use as the explorer's
 * Rust-frontend bypass while the in-wasm path (rsToIR) catches up.
 *
 * The emitted IR is compatible with `compile()`'s `mtriple` override
 * exactly like clang-produced IR, so the wasm tail
 * (`llvm-mov-llc.wasm → as.wasm → ld.wasm`) accepts it without
 * needing the i686-aware rustc.wasm artefact.
 */
export function rsHostToIR(source: string, opts?: RsHostToIROptions): Promise<string>;
