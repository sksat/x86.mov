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
// Loads the MEMFS-mode wasm artifacts from ./build/browser/. Each call
// instantiates a fresh module because the underlying tools terminate via
// exit() (EXIT_RUNTIME=1), making the runtime non-reusable.

import createMovCpp from './build/browser/cpp.js';
import createMovRcc from './build/browser/rcc.js';
import createMovAs  from './build/browser/as.js';
import createMovLd  from './build/browser/ld.js';

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

// Caller-supplied names land at `/${name}` in MEMFS (header sidecars in
// preprocess(); the .o basename in link()). Reject anything that could
// escape the root or overwrite our staged libc / crt files.
function assertSafeName(name, kind) {
    if (typeof name !== 'string' || name.length === 0) {
        throw new TypeError(`${kind} must be a non-empty string`);
    }
    if (name === '.' || name === '..'
        || name.includes('/') || name.includes('\\')) {
        throw new Error(`${kind} ${JSON.stringify(name)} must be a basename without path separators`);
    }
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
        assertSafeName(name, 'header name');
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
// particular gcc release. Exported so test harnesses can pre-stage the
// same set without duplicating the list.
export const LIB_PATHS = [
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

// Normalize the link-time objects argument into a list of {name, bytes}
// pairs ordered the same way they should appear on the ld command line.
// Accepts the three shapes we expose: single Uint8Array, an array, or a
// name→bytes map. Single-input uses opts.name (or 'a.out.o'); arrays get
// auto-numbered names ('obj0.o', 'obj1.o', …); maps' keys are used as-is.
function normalizeObjs(objs, defaultName) {
    if (objs instanceof Uint8Array) {
        return [{ name: defaultName, bytes: objs }];
    }
    if (Array.isArray(objs)) {
        return objs.map((bytes, i) => {
            if (!(bytes instanceof Uint8Array)) {
                throw new TypeError(`objs[${i}] must be Uint8Array`);
            }
            return { name: `obj${i}.o`, bytes };
        });
    }
    if (objs && typeof objs === 'object') {
        return Object.entries(objs).map(([name, bytes]) => {
            if (!(bytes instanceof Uint8Array)) {
                throw new TypeError(`objs[${JSON.stringify(name)}] must be Uint8Array`);
            }
            return { name, bytes };
        });
    }
    throw new TypeError('objs must be Uint8Array | Uint8Array[] | Record<string, Uint8Array>');
}

// MEMFS paths supplied via opts.extraInputs must be absolute, no `..`,
// and outside the directories link() relies on — overwriting those would
// corrupt the staged crt/libc. The denylist of reserved prefixes is
// derived from the wrapper's own staging set (LIB_PATHS dirs) so it
// stays in sync if the layout changes.
const RESERVED_EXTRA_INPUT_PREFIXES = ['/movfuscator/', '/lib32/', '/lib/', '/usr/lib32/'];
function assertSafeExtraInputPath(p, userObjPaths) {
    if (typeof p !== 'string' || !p.startsWith('/') || p.length < 2) {
        throw new Error(`extraInputs path ${JSON.stringify(p)} must be absolute`);
    }
    if (p.includes('/../') || p.endsWith('/..') || p.includes('//')) {
        throw new Error(`extraInputs path ${JSON.stringify(p)} contains traversal or empty segment`);
    }
    for (const pre of RESERVED_EXTRA_INPUT_PREFIXES) {
        if (p.startsWith(pre)) {
            throw new Error(
                `extraInputs path ${JSON.stringify(p)} is under wrapper-reserved directory `
                + `${JSON.stringify(pre)} (would overwrite staged crt / libc / libgcc)`,
            );
        }
    }
    if (userObjPaths.has(p)) {
        throw new Error(`extraInputs path ${JSON.stringify(p)} collides with a user object basename`);
    }
}

/**
 * Link one or more ELF32 i386 relocatable objects into a
 * dynamically-linked mov-only ELF executable.
 *
 * @param {Uint8Array | Uint8Array[] | Record<string,Uint8Array>} objs
 *   - Uint8Array: single .o (the original shape). Staged at
 *     `/${opts.name || 'a.out.o'}`.
 *   - Uint8Array[]: each element staged at `/obj<i>.o`, in order.
 *   - Record<string,Uint8Array>: keys are basenames; each entry staged
 *     at `/${name}` and added to the link command in iteration order.
 *     The basenames appear in the resulting ELF's `.symtab`.
 * @param {Record<string,Uint8Array>} [libs]
 *   MEMFS path → byte content for every entry in LIB_PATHS. If omitted,
 *   the wrapper lazy-fetches the default bundle from `./lib/` and
 *   caches it.
 * @param {{
 *   name?: string,
 *   extraLibs?: string[],
 *   searchPaths?: string[],
 *   extraInputs?: Record<string,Uint8Array>,
 * }} [opts]
 *   - `name`: only used when `objs` is a single Uint8Array. Default `a.out.o`.
 *   - `extraLibs`: appended as `-l<name>` (after the default `-lgcc -lc -lm`).
 *   - `searchPaths`: appended as `-L<path>` (after the default `-L/movfuscator
 *     -L/usr/lib32 -L/lib32`).
 *   - `extraInputs`: absolute MEMFS path → bytes, written before ld runs.
 *     Use this to stage caller-supplied `.a` files / link scripts that
 *     `extraLibs` and `searchPaths` then resolve.
 * @returns {Promise<Uint8Array>} ELF32 executable bytes
 */
export async function link(objs, libs, opts = {}) {
    const {
        name = 'a.out.o',
        extraLibs = [],
        searchPaths = [],
        extraInputs = {},
    } = opts;
    assertSafeName(name, 'opts.name');
    const userObjs = normalizeObjs(objs, name);
    for (const { name: n } of userObjs) assertSafeName(n, 'object basename');
    const userObjPaths = new Set(userObjs.map(({ name: n }) => `/${n}`));
    for (const p of Object.keys(extraInputs)) {
        assertSafeExtraInputPath(p, userObjPaths);
    }
    if (!Array.isArray(extraLibs) || !Array.isArray(searchPaths)) {
        throw new TypeError('extraLibs / searchPaths must be arrays');
    }

    if (!libs) {
        if (!cachedLibs) cachedLibs = defaultFetchLibs();
        libs = await cachedLibs;
    } else {
        // Caller supplied a pre-staged lib map. The link command line
        // requires every default LIB_PATHS entry to be present, so fail
        // fast with a list of missing paths rather than letting ld emit
        // a less helpful "file not found" later.
        const missing = LIB_PATHS.filter(p => !(p in libs));
        if (missing.length > 0) {
            throw new Error(`libs map is missing required entries: ${missing.join(', ')}`);
        }
    }
    const buf = makeBuffered();
    const ld = await createMovLd(buf.opts);
    for (const [path, bytes] of Object.entries(libs)) {
        const dir = path.substring(0, path.lastIndexOf('/'));
        if (dir) try { ld.FS.mkdirTree(dir); } catch (e) { /* already exists */ }
        ld.FS.writeFile(path, bytes);
    }
    for (const [path, bytes] of Object.entries(extraInputs)) {
        const dir = path.substring(0, path.lastIndexOf('/'));
        if (dir) try { ld.FS.mkdirTree(dir); } catch (e) { /* already exists */ }
        ld.FS.writeFile(path, bytes);
    }
    for (const { name: n, bytes } of userObjs) {
        ld.FS.writeFile(`/${n}`, bytes);
    }

    // crt0 first, user objects in caller-given order, then crtf/crtd/softfloat.
    // -L/movfuscator covers the crt + softfloat objects and libgcc.a (staged
    // together) so the wrapper isn't tied to a particular gcc release.
    const cmd = [
        '-m', 'elf_i386', '--hash-style=gnu',
        '-dynamic-linker', '/lib/ld-linux.so.2',
        '-L/movfuscator', '-L/usr/lib32', '-L/lib32',
        ...searchPaths.map(p => `-L${p}`),
        '-lgcc', '-lc', '-lm',
        ...extraLibs.map(l => `-l${l}`),
        '/movfuscator/crt0.o',
        ...userObjs.map(({ name: n }) => `/${n}`),
        '/movfuscator/crtf.o', '/movfuscator/crtd.o',
        '/movfuscator/softfloat32.o',
        '-o', '/out.elf',
    ];
    const exit = ld.callMain(cmd);
    if (exit !== 0) {
        throw new Error(`ld exited ${exit}\n${buf.joined()}`);
    }
    return ld.FS.readFile('/out.elf');
}

/**
 * Convenience: full C → mov-only ELF executable in one call.
 *
 * @param {string | Record<string,string>} source
 *   - string: single .c. Equivalent to
 *     `link(await assemble(await compile(source, headers)), undefined, linkOpts)`.
 *   - Record<string,string>: multi-file. Sources are concatenated into a
 *     single translation unit (with `#line` markers preserving per-file
 *     diagnostics), compiled once, and the resulting single .o is linked.
 *     This sidesteps an upstream movfuscator cross-`.o` ABI bug — see
 *     issue #9 / the comment in this function for the long story.
 * @param {Record<string,string>} [headers] `name.h` → content map shared
 *   across every .c in `source`. Header sidecars are staged in MEMFS root
 *   so `#include "name.h"` resolves.
 * @param {object} [linkOpts] forwarded to link() (`name`, `extraLibs`,
 *   `searchPaths`, `extraInputs`).
 * @returns {Promise<Uint8Array>} ELF32 executable bytes
 */
export async function compileToElf(source, headers = {}, linkOpts = {}) {
    if (typeof source === 'string') {
        return link(await assemble(await compile(source, headers)), undefined, linkOpts);
    }
    if (!source || typeof source !== 'object') {
        throw new TypeError('source must be a string or Record<string,string>');
    }
    const entries = Object.entries(source);
    for (const [name] of entries) assertSafeName(name, 'source basename');
    if (entries.length === 0) {
        throw new TypeError('source must have at least one entry');
    }
    // Multi-source: amalgamate into one TU. Upstream movfuscator decides
    // the internal-vs-external CALL protocol per translation unit
    // (movfuscator.c:3538 — `ext = !s || s->sclass == EXTERN`). When two
    // `.o`s defined in separate TUs reference each other, the caller
    // emits the libc-style external-trampoline protocol while the callee
    // waits on the internal compare protocol, and `master_loop`
    // deadlocks. Routing every CALL through a single TU keeps both sides
    // on the internal protocol — almost. The combine alone isn't enough:
    // a leftover `extern int add(...)` declaration in one piece will
    // still mark the symbol's sclass as EXTERN and re-trigger the bug
    // even when the definition lives in the very same amalgam.
    // Workaround: scan every source for top-level function definitions
    // and prepend a non-`extern` prototype (`retType name();` K&R form)
    // for each one. C allows a non-`extern` prototype to follow a later
    // ANSI prototype with full args, and lcc treats the resulting symbol
    // as non-EXTERN — which is exactly what we want at every CALL site.
    const seen = new Set();
    const shadowProtos = [];
    for (const [, src] of entries) {
        for (const def of scanDefinedFunctions(src)) {
            if (seen.has(def.name)) continue;
            seen.add(def.name);
            shadowProtos.push(`${def.retType} ${def.name}();`);
        }
    }
    const amalgam =
        (shadowProtos.length ? shadowProtos.join('\n') + '\n' : '') +
        entries
            .map(([name, src]) => `#line 1 "${name}.c"\n${src}`)
            .join('\n');
    return link(await assemble(await compile(amalgam, headers)), undefined, linkOpts);
}

// Best-effort scanner for top-level function definitions in a `.c` source.
// Matches the typical fixture style — `[storage/qualifier]* returnType name(args) {`
// on a single line, no leading indentation. Misses K&R definitions, defs
// whose header spans multiple lines, and function-pointer return types;
// those aren't represented in our current fixtures and falling back to a
// missing shadow on them just reproduces the original deadlock without
// silently mis-compiling.
function scanDefinedFunctions(src) {
    const re = /^([A-Za-z_][\w\s*]*?)\b([A-Za-z_]\w*)\s*\([^)]*\)\s*\{/gm;
    const defs = [];
    let m;
    while ((m = re.exec(src)) !== null) {
        const retType = m[1].trim();
        const name = m[2];
        if (retType.length === 0) continue;
        defs.push({ retType, name });
    }
    return defs;
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
