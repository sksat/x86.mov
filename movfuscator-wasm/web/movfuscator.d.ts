// Type declarations for movfuscator-wasm.
//
// The runtime is plain JS (movfuscator.mjs); these typings exist so
// downstream TS projects can `import { compile, link } from
// 'movfuscator-wasm'` without `// @ts-ignore`.

/** Mapping of `name.h` → file content, mounted in MEMFS root so the
 *  user's source can `#include "name.h"`. */
export type Headers = Record<string, string>;

/** Mapping of absolute MEMFS path → bytes, used to inject a fully
 *  pre-staged lib bundle into `link()`. If omitted, the wrapper
 *  lazy-fetches the default bundle from `./lib/` next to the module. */
export type LinkLibs = Record<string, Uint8Array>;

export interface LinkOptions {
  /** Basename used when staging the .o into MEMFS. Surfaces in the
   *  resulting ELF's `.symtab`; defaults to `a.out.o`. */
  name?: string;
}

/** Run the LCC C preprocessor on `source`. Returns the post-`#include`
 *  text (`.i`). */
export function preprocess(source: string, headers?: Headers): Promise<string>;

/** Run just the mov-only code generator on preprocessed C source.
 *  Pair with `preprocess()` to interpose between the two stages. */
export function compileAsm(preprocessed: string): Promise<string>;

/** Compile C source → mov-only x86 assembly (.s text). */
export function compile(source: string, headers?: Headers): Promise<string>;

/** Assemble x86 mov-only asm → ELF32 i386 relocatable object (.o). */
export function assemble(asm: string): Promise<Uint8Array>;

/** Link a .o into a dynamically-linked mov-only ELF32 executable.
 *  On first call without `libs`, lazy-fetches the ~24 MB crt + libc +
 *  libgcc bundle from `./lib/` and caches it for subsequent calls. */
export function link(
  obj: Uint8Array,
  libs?: LinkLibs,
  opts?: LinkOptions,
): Promise<Uint8Array>;

/** Convenience: full C → linked ELF in one call. */
export function compileToElf(
  source: string,
  headers?: Headers,
  linkOpts?: LinkOptions,
): Promise<Uint8Array>;

export interface ElfHeader {
  class: 'ELF32';
  data: 'little-endian';
  /** ELF e_type (REL / EXEC / DYN / CORE / unknown). */
  type: string;
  /** ELF e_machine (i386 / unknown). */
  machine: string;
  /** ELF e_entry, formatted as 0xNNNNNNNN. */
  entry: string;
  /** ELF e_shnum (section header count). */
  sections: number;
}

/** Decode the ELF32 header of `bytes`. Returns `null` on bad magic /
 *  too-short input; `{ raw }` on unsupported class/data; an `ElfHeader`
 *  otherwise. */
export function parseElfHeader(
  bytes: Uint8Array,
): null | { raw: string } | ElfHeader;
