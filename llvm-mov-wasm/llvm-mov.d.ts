export interface CompileOptions {
    /**
     * Basename used for the MEMFS input file. The native driver bakes
     * the input filename into a `.file "<name>"` directive, so matching
     * it here is required for byte-identical parity with native
     * `llvm-mov-llc`. Defaults to `in.ll`.
     */
    name?: string;
}

/**
 * Compile LLVM IR (.ll text) to mov-target x86-32 assembly (.s text).
 * @param ir LLVM IR source text. If it lacks a `target triple = "..."`
 *   line, the driver defaults to `mov-unknown-linux-gnu`.
 * @returns mov-target x86-32 GAS-syntax assembly text
 */
export function compile(ir: string, opts?: CompileOptions): Promise<string>;
