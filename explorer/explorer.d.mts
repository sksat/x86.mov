// Sidecar TS declarations for the framework-free orchestration
// module. TS auto-picks `<basename>.d.mts` next to a .mjs import, so
// the React app (`src/lib/compiler.ts`) sees real types here while the
// Node unit suite (`tests/unit.test.mjs`) keeps using the runtime
// module directly.

export const COMPILERS: readonly ('movfuscator' | 'llvm-mov')[];

export interface CompileWrappers {
    movfuscator?: {
        compile(source: string, headers?: Record<string, string>): Promise<string>;
        assemble(asm: string): Promise<Uint8Array>;
        link(
            objs: Uint8Array | Uint8Array[] | Record<string, Uint8Array>,
            libs?: Record<string, Uint8Array> | undefined,
            opts?: {
                name?: string;
                static?: boolean;
                runtime?: 'movfuscator' | 'none';
                extraLibs?: string[];
                searchPaths?: string[];
                extraInputs?: Record<string, Uint8Array>;
            },
        ): Promise<Uint8Array>;
    };
    llvmMov?: {
        cToIR(
            source: string,
            opts?: {
                optLevel?: '0' | '1' | '2' | '3' | 's' | 'z';
                clangFlags?: string[];
            },
        ): Promise<string>;
        compile(
            ir: string,
            opts?: { mtriple?: string },
        ): Promise<string>;
    };
}

export interface CompileParams {
    compiler: 'movfuscator' | 'llvm-mov';
    source: string;
    opts?: {
        optLevel?: '0' | '1' | '2' | '3' | 's' | 'z';
        clangFlags?: string[];
        headers?: Record<string, string>;
        linkOpts?: {
            name?: string;
            /** Drops `-dynamic-linker`; adds `-static`. movie86 requires
             *  this. Defaults to `true` on the llvm-mov path inside
             *  explorer.mjs; caller can override either way. */
            static?: boolean;
            /** Which CRT objects the wrapper auto-wraps the inputs in.
             *  `'movfuscator'` (default) or `'none'`. */
            runtime?: 'movfuscator' | 'none';
            extraLibs?: string[];
            searchPaths?: string[];
            extraInputs?: Record<string, Uint8Array>;
        };
        onProgress?: (stage: string) => void;
    };
    wrappers?: CompileWrappers;
}

export interface CompileResult {
    compiler: 'movfuscator' | 'llvm-mov';
    ir: string | null;
    asm: string;
    obj: Uint8Array;
    elf: Uint8Array;
    timings: Record<string, number>;
}

export function compileWithCompiler(params: CompileParams): Promise<CompileResult>;
