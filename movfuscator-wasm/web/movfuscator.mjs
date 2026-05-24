// movfuscator-wasm: in-browser (or Node ESM) C → mov-only ELF compiler.
//
// Usage:
//   import { compile, assemble } from './movfuscator.mjs';
//   const asm = await compile('int main(void){return 42;}');  // C → .s text
//   const obj = await assemble(asm);                          // .s → .o bytes
//   // Multi-file: provide header sidecars for `#include "name.h"` style:
//   const asm2 = await compile(src, { 'md5.h': headerText });
//
// Loads the MEMFS-mode wasm artifacts from ../build/browser/. Each call
// instantiates a fresh module because the underlying tools terminate via
// exit() (EXIT_RUNTIME=1), making the runtime non-reusable.

import createMovCpp from '../build/browser/cpp.js';
import createMovRcc from '../build/browser/rcc.js';
import createMovAs  from '../build/browser/as.js';

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
// cpp and rcc both write progress notes and warnings (M/o/Vfuscator
// banner, "Unknown preprocessor control warning", emit/mov> dump, etc.)
// to stderr. Emscripten's default printErr routes that to console.error,
// which the browser DevTools paints red — alarming for non-errors.
// We capture stderr into a buffer instead: silent on success, included
// in the thrown error on non-zero exit.
function makeBuffered() {
    const lines = [];
    return {
        opts: { print: () => {}, printErr: (s) => lines.push(s) },
        joined: () => lines.join('\n'),
    };
}

export async function compile(source, headers = {}) {
    const cppBuf = makeBuffered();
    const cpp = await createMovCpp(cppBuf.opts);
    for (const [name, content] of Object.entries(headers)) {
        cpp.FS.writeFile(`/${name}`, content);
    }
    cpp.FS.writeFile('/in.c', source);
    const cppExit = cpp.callMain([...CPP_FLAGS, '/in.c', '/in.i']);
    if (cppExit !== 0) {
        throw new Error(`cpp exited ${cppExit}\n${cppBuf.joined()}`);
    }
    const preprocessed = cpp.FS.readFile('/in.i', { encoding: 'utf8' });

    const rccBuf = makeBuffered();
    const rcc = await createMovRcc(rccBuf.opts);
    rcc.FS.writeFile('/in.i', preprocessed);
    const rccExit = rcc.callMain(['-target=x86/mov', '/in.i', '/out.s']);
    if (rccExit !== 0) {
        throw new Error(`rcc exited ${rccExit}\n${rccBuf.joined()}`);
    }
    return rcc.FS.readFile('/out.s', { encoding: 'utf8' });
}

/**
 * Assemble x86 mov-only asm text to an ELF32 i386 relocatable object.
 * @param {string} asm assembly text (the kind compile() returns)
 * @returns {Promise<Uint8Array>} ELF32 .o bytes
 */
export async function assemble(asm) {
    const buf = makeBuffered();
    const as = await createMovAs(buf.opts);
    as.FS.writeFile('/in.s', asm);
    // -mx86-used-note=no keeps output byte-aligned with the host /usr/bin/as
    // (modern binutils default-emits an .note.gnu.property section).
    const exit = as.callMain(['--32', '-mx86-used-note=no', '-o', '/out.o', '/in.s']);
    if (exit !== 0) {
        throw new Error(`as exited ${exit}\n${buf.joined()}`);
    }
    return as.FS.readFile('/out.o');  // Uint8Array
}
