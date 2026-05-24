// movfuscator-wasm: in-browser (or Node ESM) C → mov-only x86 asm compiler.
//
// Usage:
//   import { compile } from './movfuscator.mjs';
//   const asm = await compile('int main(void){return 42;}');
//   // Multi-file: provide header sidecars for `#include "name.h"` style:
//   const asm2 = await compile(src, { 'md5.h': headerText });
//
// Loads the MEMFS-mode wasm artifacts from ../build/browser/. Each call
// instantiates fresh cpp and rcc modules because both terminate via exit()
// (EXIT_RUNTIME=1), which makes their runtime non-reusable.

import createMovCpp from '../build/browser/cpp.js';
import createMovRcc from '../build/browser/rcc.js';

// Matches the predefined macros the native lcc driver passes to cpp.
// Same set used by tests/run.sh so the wasm and native pipelines stay
// bit-aligned.
const CPP_FLAGS = [
    '-U__GNUC__',
    '-D_POSIX_SOURCE', '-D__STRICT_ANSI__',
    '-Dunix', '-Di386', '-Dlinux',
    '-D__unix__', '-D__i386__', '-D__linux__',
    '-D__signed__=signed',
    '-D__LCC__',
    '-I/lcc-include',
    '-I/gcc-include',
    '-I/usr/include',
];

/**
 * Compile C source to mov-only x86 assembly.
 * @param {string} source raw C source code
 * @param {Record<string,string>} [headers] optional `name.h` → content map
 *   placed in MEMFS root so `#include "name.h"` resolves alongside the input
 * @returns {Promise<string>} mov-only x86 assembly (.s text)
 */
export async function compile(source, headers = {}) {
    const cpp = await createMovCpp();
    for (const [name, content] of Object.entries(headers)) {
        cpp.FS.writeFile(`/${name}`, content);
    }
    cpp.FS.writeFile('/in.c', source);
    const cppExit = cpp.callMain([...CPP_FLAGS, '/in.c', '/in.i']);
    if (cppExit !== 0) {
        throw new Error(`cpp exited ${cppExit}`);
    }
    const preprocessed = cpp.FS.readFile('/in.i', { encoding: 'utf8' });

    const rcc = await createMovRcc();
    rcc.FS.writeFile('/in.i', preprocessed);
    const rccExit = rcc.callMain(['-target=x86/mov', '/in.i', '/out.s']);
    if (rccExit !== 0) {
        throw new Error(`rcc exited ${rccExit}`);
    }
    return rcc.FS.readFile('/out.s', { encoding: 'utf8' });
}
