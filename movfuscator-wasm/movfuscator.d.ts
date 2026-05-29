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

/** The default MEMFS paths the wrapper writes when `link()` runs
 *  (matches the layout under `./lib/` shipped with the package). Exported
 *  so test harnesses or other callers can pre-stage a `LinkLibs` map
 *  without duplicating the list. */
export const LIB_PATHS: readonly string[];

export interface LinkOptions {
  /** Basename used when staging a single .o into MEMFS. Surfaces in the
   *  resulting ELF's `.symtab`; defaults to `a.out.o`. Ignored when
   *  `objs` is an array or Record (those carry their own basenames). */
  name?: string;
  /** Link statically. Drops `-dynamic-linker /lib/ld-linux.so.2` and the
   *  default `-lgcc -lc -lm`, adds `-static`. The output has no
   *  PT_INTERP / PT_DYNAMIC, so it can be loaded by movie86 (which
   *  rejects dynamic ELFs at `Vm::new`). Suitable for the
   *  movfuscator-CRT-only programs that don't call into libc; if the
   *  caller needs libc symbols, they can re-introduce them with
   *  `extraLibs: ['c', ...]` plus a libc.a staged via `extraInputs`.
   *  Default `false`. */
  static?: boolean;
  /** Extra `-l<name>` flags appended after the per-mode defaults
   *  (`-lgcc -lc -lm` in dynamic mode, none in static mode). */
  extraLibs?: string[];
  /** Extra `-L<path>` search paths appended after the default
   *  `-L/movfuscator -L/usr/lib32 -L/lib32`. */
  searchPaths?: string[];
  /** Absolute MEMFS path → bytes, staged before ld runs. Use to provide
   *  caller-supplied `.a` archives or link scripts that `extraLibs` /
   *  `searchPaths` then resolve. Paths must be absolute and outside the
   *  directories the wrapper relies on (e.g., `/movfuscator/`). */
  extraInputs?: Record<string, Uint8Array>;
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

/** Link one or more .o files into a dynamically-linked mov-only ELF32
 *  executable.
 *
 *  - `Uint8Array`: single .o, staged at `/${opts.name || 'a.out.o'}`.
 *  - `Uint8Array[]`: each element gets a synthetic `obj<i>.o` name.
 *  - `Record<string, Uint8Array>`: keys are basenames; entries are linked
 *    in iteration order with those names visible in the ELF `.symtab`.
 *
 *  On first call without `libs`, lazy-fetches the ~24 MB crt + libc +
 *  libgcc bundle from `./lib/` and caches it for subsequent calls. */
export function link(
  objs: Uint8Array | Uint8Array[] | Record<string, Uint8Array>,
  libs?: LinkLibs,
  opts?: LinkOptions,
): Promise<Uint8Array>;

/** Convenience: full C → linked ELF in one call.
 *
 *  - `string` source: single .c (the original shape).
 *  - `Record<string, string>` source: multi-file. Each `[basename, .c]`
 *    is compiled + assembled, then all .o are linked together. The
 *    basenames appear in the resulting ELF's `.symtab`. */
export function compileToElf(
  source: string | Record<string, string>,
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
