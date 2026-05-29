// Runtime loaders for the three sibling wasm wrappers.
//
// The Explorer doesn't bundle these (they reference giant binary
// chunks: ~24 MB libs for movfuscator's link step, ~80 MB clang.wasm
// for llvm-mov-wasm). Each subproject stays on its own deployed URL
// space (`/movfuscator-wasm/`, `/movie86/`, `/llvm-mov/`) and we
// dynamic-import their entry `.mjs` from a path that resolves
// identically in dev (Vite root: explorer/, fs.allow=..) and in
// production (siblings under dist/).
//
// We deliberately go through `import(/* @vite-ignore */ new URL(...,
// import.meta.url).href)` so Vite leaves the URL alone — otherwise its
// pre-bundler would try to crawl the wrapper's internal `./build/...`
// imports at build time, when those bytes may not exist (each
// subproject's `make build` produces them separately).

export interface MovfuscatorWrapper {
    compile(source: string, headers?: Record<string, string>): Promise<string>;
    assemble(asm: string): Promise<Uint8Array>;
    link(
        objs: Uint8Array | Uint8Array[] | Record<string, Uint8Array>,
        libs?: Record<string, Uint8Array>,
        opts?: { name?: string; extraLibs?: string[]; searchPaths?: string[] },
    ): Promise<Uint8Array>;
    compileToElf(
        source: string | Record<string, string>,
        headers?: Record<string, string>,
        linkOpts?: object,
    ): Promise<Uint8Array>;
    parseElfHeader(bytes: Uint8Array): null | { raw: string } | {
        class: 'ELF32';
        data: 'little-endian';
        type: string;
        machine: string;
        entry: string;
        sections: number;
    };
}

export interface LlvmMovWrapper {
    compile(
        ir: string,
        opts?: { name?: string; mtriple?: string; onProgress?: (ev: { stage: string }) => void },
    ): Promise<string>;
    cToIR(
        source: string,
        opts?: {
            name?: string;
            optLevel?: '0' | '1' | '2' | '3' | 's' | 'z';
            clangFlags?: string[];
            onProgress?: (ev: { stage: string }) => void;
        },
    ): Promise<string>;
    compileC(
        source: string,
        opts?: {
            name?: string;
            optLevel?: '0' | '1' | '2' | '3' | 's' | 'z';
            clangFlags?: string[];
            mtriple?: string;
            onProgress?: (ev: { stage: string }) => void;
        },
    ): Promise<string>;
}

export interface Movie86Wrapper {
    /** Construct a Vm from ELF bytes. The wrapper auto-runs `init()` on
     *  first call (lazy wasm load). */
    loadVm(bytes: Uint8Array, opts?: { maxSteps?: number }): Promise<Movie86Vm>;
    runElf(bytes: Uint8Array, opts?: { maxSteps?: number }): Promise<{
        stdout: string;
        stderr: string;
        stdoutBytes: Uint8Array;
        stderrBytes: Uint8Array;
        exitCode: number | null;
        haltReason: string | null;
        steps: bigint;
    }>;
    FRAMEBUFFER_MODES: readonly {
        id: string;
        modeNumber: number;
        addr: number;
        width: number;
        height: number;
        bytesPerPixel: 4;
        byteLength: number;
    }[];
    modeForNumber(n: number): { id: string; modeNumber: number; addr: number; width: number; height: number; byteLength: number } | undefined;
    snapshotContext(vm: Movie86Vm): {
        regs: Record<string, number>;
        regions: { addr: number; bytes: Uint8Array }[];
    };
    loadContextInto(
        vm: Movie86Vm,
        ctx: { regs: Record<string, number>; regions: { addr: number; bytes: Uint8Array }[] },
    ): { applied: number; skipped: number };
    makeLoadContextMessage(
        ctx: { regs: Record<string, number>; regions: { addr: number; bytes: Uint8Array }[] },
        mode?: 'host' | 'trap',
    ): string;
    parseOutboundMessage(text: string): { type: string; [k: string]: unknown };
}

export interface Movie86Vm {
    free(): void;
    stepN(n: bigint): void;
    drainStdout(): Uint8Array;
    drainStderr(): Uint8Array;
    disasmAt(addr: number): null | { bytes: Uint8Array; text: string; len: number; free(): void };
    readMem(addr: number, len: number): Uint8Array;
    readonly regs: Uint32Array;
    readonly eip: number;
    readonly steps: bigint;
    readonly haltReason: string | null;
    readonly exitCode: number | null;
    readonly memBase: number;
    readonly memLen: number;
    readonly sigsegvHandler: number | null;
    readonly sigillHandler: number | null;
    readonly activeVideoMode: number | null;
}

// Sibling subprojects are deployed alongside this page (so /explorer/
// sees /movfuscator-wasm/, /movie86/, /llvm-mov/ as siblings on the
// same origin — the per-subproject `stage-deploy.sh` files flatten
// `<subproject>/wasm/` down to `dist/<subproject>/` for movie86 and
// llvm-mov, while movfuscator-wasm already lives at its own root).
//
// We resolve against `document.baseURI` instead of `import.meta.url`
// so Rollup can't statically validate the URL at build time — its
// build-stage resolver still tries to crawl
// `new URL(string-literal, import.meta.url)` even when the dynamic
// import is marked `/* @vite-ignore */`, and the sibling wrappers
// internally reference build artifacts that may not exist yet (each
// subproject builds independently).
//
// Dev mode: `vite.config.ts` adds a middleware that maps the request
// URLs below back to the source-tree layout (`../movie86/wasm/...`
// etc.), so the same URLs work whether served by `vite dev` or by
// Cloudflare Pages.
function siblingUrl(subpath: string): string {
    const base = typeof document !== 'undefined'
        ? document.baseURI
        : 'http://localhost/';
    return new URL(`../${subpath}`, base).href;
}

// Vite's prebundler / Rollup will silently follow `import(literal)`
// even with the `@vite-ignore` comment. Routing through an indirect
// `globalThis['import']` call would defeat module resolution at the
// engine layer. Instead, assign `import` to a non-inlineable function
// reference and call via that — the compiler can no longer trace the
// argument.
const dynamicImport: (specifier: string) => Promise<unknown> =
    /* @__PURE__ */ (new Function(
        'specifier',
        'return import(specifier);',
    )) as (specifier: string) => Promise<unknown>;

let _movfuscator: Promise<MovfuscatorWrapper> | null = null;
export function loadMovfuscator(): Promise<MovfuscatorWrapper> {
    if (!_movfuscator) {
        _movfuscator = dynamicImport(
            siblingUrl('movfuscator-wasm/movfuscator.mjs'),
        ) as Promise<MovfuscatorWrapper>;
    }
    return _movfuscator;
}

let _llvmMov: Promise<LlvmMovWrapper> | null = null;
export function loadLlvmMov(): Promise<LlvmMovWrapper> {
    if (!_llvmMov) {
        // Deploy URL is `/llvm-mov/llvm-mov.mjs` (stage-deploy flattens
        // the `wasm/` segment). Vite dev middleware in vite.config.ts
        // maps this back to `../llvm-mov/wasm/llvm-mov.mjs`.
        _llvmMov = dynamicImport(
            siblingUrl('llvm-mov/llvm-mov.mjs'),
        ) as Promise<LlvmMovWrapper>;
    }
    return _llvmMov;
}

let _movie86: Promise<Movie86Wrapper> | null = null;
export function loadMovie86(): Promise<Movie86Wrapper> {
    if (!_movie86) {
        // Deploy URL is `/movie86/movie86.mjs` (stage-deploy flattens
        // the `wasm/` segment). Vite dev middleware maps this back to
        // `../movie86/wasm/movie86.mjs`.
        _movie86 = dynamicImport(
            siblingUrl('movie86/movie86.mjs'),
        ) as Promise<Movie86Wrapper>;
    }
    return _movie86;
}
