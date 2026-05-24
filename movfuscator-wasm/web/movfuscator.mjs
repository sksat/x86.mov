// movfuscator-wasm: in-browser (or Node ESM) C → mov-only ELF compiler.
//
// Usage:
//   import { compile, assemble, link, compileToElf } from './movfuscator.mjs';
//   const asm = await compile('int main(void){return 42;}');  // C → .s text
//   const obj = await assemble(asm);                          // .s → .o bytes
//   const elf = await link(obj);                              // .o → ELF
//   // Or all-in-one:
//   const elf2 = await compileToElf('int main(void){return 42;}');
//   // Multi-file: provide header sidecars for `#include "name.h"` style:
//   const asm2 = await compile(src, { 'md5.h': headerText });
//
// Loads the MEMFS-mode wasm artifacts from ../build/browser/. Each call
// instantiates a fresh module because the underlying tools terminate via
// exit() (EXIT_RUNTIME=1), making the runtime non-reusable.

import createMovCpp from '../build/browser/cpp.js';
import createMovRcc from '../build/browser/rcc.js';
import createMovAs  from '../build/browser/as.js';
import createMovLd  from '../build/browser/ld.js';

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

/**
 * Run just the C preprocessor (LCC cpp) on the input. Useful if you want
 * to inspect the post-#include text or feed it into a non-mov backend.
 * @param {string} source raw C source code
 * @param {Record<string,string>} [headers] optional `name.h` → content map
 * @returns {Promise<string>} preprocessed C source (.i text)
 */
export async function preprocess(source, headers = {}) {
    const buf = makeBuffered();
    const cpp = await createMovCpp(buf.opts);
    for (const [name, content] of Object.entries(headers)) {
        cpp.FS.writeFile(`/${name}`, content);
    }
    cpp.FS.writeFile('/in.c', source);
    const exit = cpp.callMain([...CPP_FLAGS, '/in.c', '/in.i']);
    if (exit !== 0) {
        throw new Error(`cpp exited ${exit}\n${buf.joined()}`);
    }
    return cpp.FS.readFile('/in.i', { encoding: 'utf8' });
}

/**
 * Run just the mov-only code generator on already-preprocessed source.
 * Pair with preprocess() if you want to interpose between the two stages.
 * @param {string} preprocessed C source after cpp (the kind preprocess() returns)
 * @returns {Promise<string>} mov-only x86 assembly (.s text)
 */
export async function compileAsm(preprocessed) {
    const buf = makeBuffered();
    const rcc = await createMovRcc(buf.opts);
    rcc.FS.writeFile('/in.i', preprocessed);
    const exit = rcc.callMain(['-target=x86/mov', '/in.i', '/out.s']);
    if (exit !== 0) {
        throw new Error(`rcc exited ${exit}\n${buf.joined()}`);
    }
    return rcc.FS.readFile('/out.s', { encoding: 'utf8' });
}

export async function compile(source, headers = {}) {
    return compileAsm(await preprocess(source, headers));
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

// MEMFS paths wasm-ld reads at link time. Most mirror real host paths so
// the link command line stays close to what `/usr/bin/ld` sees on the
// host; libgcc.a is parked under /movfuscator/ instead of its
// gcc-version-specific host location so the wrapper isn't tied to a
// particular gcc release.
const LIB_PATHS = [
    '/lib32/libc.so.6',
    '/lib32/libm.so.6',
    '/lib32/ld-linux.so.2',
    '/lib/ld-linux.so.2',         // alias the libc.so script's AS_NEEDED expects
    '/usr/lib32/libc.so',
    '/usr/lib32/libm.so',
    '/usr/lib32/libc_nonshared.a',
    '/movfuscator/libgcc.a',
    '/movfuscator/crt0.o',
    '/movfuscator/crtf.o',
    '/movfuscator/crtd.o',
    '/movfuscator/softfloat32.o',
];

// Cached lib bundle promise — populated on the first link() call so the
// ~24 MB worth of files only travels the network once per tab session.
let cachedLibs = null;

async function defaultFetchLibs() {
    // The lib bundle is sibling to this module. In a browser context that
    // resolves to https://…/lib/…; in Node (file:// import.meta.url) we
    // need fs.readFile because the global fetch can't open file: URLs.
    const base = new URL('./lib/', import.meta.url);
    let readBytes;
    if (base.protocol === 'file:') {
        const { readFile } = await import('node:fs/promises');
        const { fileURLToPath } = await import('node:url');
        readBytes = async (url) =>
            new Uint8Array(await readFile(fileURLToPath(url)));
    } else {
        readBytes = async (url) => {
            const r = await fetch(url);
            if (!r.ok) throw new Error(`fetch ${url}: ${r.status} ${r.statusText}`);
            return new Uint8Array(await r.arrayBuffer());
        };
    }
    const out = {};
    await Promise.all(LIB_PATHS.map(async (p) => {
        const url = new URL(p.replace(/^\//, ''), base);
        out[p] = await readBytes(url);
    }));
    return out;
}

/**
 * Link an ELF32 i386 relocatable object into a dynamically-linked
 * mov-only ELF executable.
 *
 * @param {Uint8Array} obj the .o produced by assemble()
 * @param {Record<string,Uint8Array>} [libs]
 *   Optional map of MEMFS path → byte content for every entry in
 *   LIB_PATHS. If omitted, the wrapper lazy-fetches them once from
 *   ./lib (caching the result for subsequent calls).
 * @param {{name?: string}} [opts]
 *   `name` is the basename used when staging the .o into MEMFS; it
 *   shows up in the resulting ELF's symbol table (.symtab) so a real
 *   filename is preferable to "user.o" if you want byte-identical
 *   output vs a host link of the same file.
 * @returns {Promise<Uint8Array>} ELF32 executable bytes
 */
export async function link(obj, libs, opts = {}) {
    const { name = 'a.out.o' } = opts;
    if (!libs) {
        if (!cachedLibs) cachedLibs = defaultFetchLibs();
        libs = await cachedLibs;
    }
    const buf = makeBuffered();
    const ld = await createMovLd(buf.opts);
    for (const [path, bytes] of Object.entries(libs)) {
        const dir = path.substring(0, path.lastIndexOf('/'));
        if (dir) try { ld.FS.mkdirTree(dir); } catch (e) { /* already exists */ }
        ld.FS.writeFile(path, bytes);
    }
    const userPath = `/${name}`;
    ld.FS.writeFile(userPath, obj);
    // -L/movfuscator covers both the crt + softfloat objects and libgcc.a
    // (staged together) so the wrapper isn't tied to a particular gcc
    // version-specific host path.
    const exit = ld.callMain([
        '-m', 'elf_i386', '--hash-style=gnu',
        '-dynamic-linker', '/lib/ld-linux.so.2',
        '-L/movfuscator', '-L/usr/lib32', '-L/lib32',
        '-lgcc', '-lc', '-lm',
        '/movfuscator/crt0.o', userPath,
        '/movfuscator/crtf.o', '/movfuscator/crtd.o',
        '/movfuscator/softfloat32.o',
        '-o', '/out.elf',
    ]);
    if (exit !== 0) {
        throw new Error(`ld exited ${exit}\n${buf.joined()}`);
    }
    return ld.FS.readFile('/out.elf');
}

/**
 * Convenience: full C → mov-only ELF executable in one call.
 * Equivalent to `link(await assemble(await compile(source, headers)), undefined, linkOpts)`.
 * @param {string} source raw C source code
 * @param {Record<string,string>} [headers] optional `name.h` → content map
 * @param {{name?: string}} [linkOpts] forwarded to link() (controls the
 *   basename embedded in the ELF's .symtab)
 * @returns {Promise<Uint8Array>} ELF32 executable bytes
 */
export async function compileToElf(source, headers = {}, linkOpts = {}) {
    return link(await assemble(await compile(source, headers)), undefined, linkOpts);
}

/**
 * Parse the ELF32 header of a byte buffer. Returns null if the magic is
 * wrong; `{ raw: '...' }` if the class/data combination isn't ELF32-LE
 * (the only flavor this wrapper produces). Otherwise an object with
 * decoded type / machine / entrypoint / section count.
 *
 * Exposed because the demo and downstream tools both want a quick
 * "is this really an ELF, and what does it look like" check without
 * pulling in a full ELF parser.
 *
 * @param {Uint8Array} bytes ELF candidate (typically link()'s output)
 * @returns {null | { raw: string } | {
 *   class: 'ELF32', data: 'little-endian',
 *   type: string, machine: string, entry: string, sections: number,
 * }}
 */
export function parseElfHeader(bytes) {
    if (bytes.length < 52 || bytes[0] !== 0x7f
        || bytes[1] !== 0x45 || bytes[2] !== 0x4c || bytes[3] !== 0x46) {
        return null;
    }
    const ei_class = bytes[4];   // 1 = ELF32, 2 = ELF64
    const ei_data  = bytes[5];   // 1 = LE
    if (ei_class !== 1 || ei_data !== 1) {
        return { raw: `unsupported ELF class=${ei_class} data=${ei_data}` };
    }
    const dv = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    const type    = dv.getUint16(16, true);
    const machine = dv.getUint16(18, true);
    const entry   = dv.getUint32(24, true);
    const shnum   = dv.getUint16(48, true);
    const typeNames = { 1: 'REL (relocatable .o)', 2: 'EXEC (executable)', 3: 'DYN', 4: 'CORE' };
    const machNames = { 3: 'i386' };
    return {
        class:    'ELF32',
        data:     'little-endian',
        type:     typeNames[type] || `unknown (${type})`,
        machine:  machNames[machine] || `unknown (${machine})`,
        entry:    '0x' + entry.toString(16).padStart(8, '0'),
        sections: shnum,
    };
}
