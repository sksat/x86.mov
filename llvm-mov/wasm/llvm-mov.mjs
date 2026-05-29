// llvm-mov-wasm: Node ESM / browser wrapper around clang.wasm +
// llvm-mov-llc.wasm.
//
// Usage (Node, after `make build`):
//   import { compileC, compile } from './llvm-mov.mjs';
//   const asm = await compileC('int main(void){ return 42; }');
//   // …or skip the C frontend and feed LLVM IR directly:
//   const asm2 = await compile('target triple="mov-..."\n…');
//
// The `.s → .o → ELF` tail of the pipeline lives in ../movfuscator-wasm
// (its `assemble` and `link` are byte-identical with host as/ld on the
// shared inputs).
//
// Each call instantiates a fresh module — the underlying drivers call
// exit() at the end of main (EXIT_RUNTIME=1), making the runtime
// non-reusable. Same shape as movfuscator-wasm's wrappers.

import { CLANG_WASM_VERSION } from './wasm-config.js';

// Drivers are lazy-loaded so callers that only use one path (e.g.
// `rsToIR` from the Rust frontend, with no built llvm-mov-llc.wasm
// in the worktree yet) don't get blocked by a missing artefact on
// the other path. The dynamic imports are cached by the host module
// loader.
let _createMovLlc = null;
async function loadLlc() {
    if (_createMovLlc === null) {
        const m = await import('./build/llvm-mov-llc.js');
        _createMovLlc = m.default;
    }
    return _createMovLlc;
}

let _createMovClang = null;
async function loadClang() {
    if (_createMovClang === null) {
        const m = await import('./build/clang.js');
        _createMovClang = m.default;
    }
    return _createMovClang;
}

// Cloudflare Pages rejects single files larger than 25 MiB at upload,
// so the deploy ships `clang.wasm-{version}.zst` instead (~14 MiB on
// the wire, 5.8× smaller than the original wasm). The `_headers` rule
// sets `Content-Encoding: zstd` on that path — modern browsers
// (Chrome 123+/Firefox 126+/Edge 123+) decompress at the network
// layer for free; other browsers (Safari today) pass the raw zstd
// bytes through, and we decompress in JS with `fzstd` (a 24 KB
// pure-JS zstd decoder we vendor next to clang.js).
//
// We tell the two cases apart by looking at the first four bytes:
//   - `\0asm` (00 61 73 6D) ⇒ wasm magic, the browser already
//     decompressed; use the buffer directly.
//   - `28 B5 2F FD`         ⇒ zstd magic, our turn to decompress.
//
// The decompressed buffer goes to Emscripten via `Module.wasmBinary`
// which suppresses the default `clang.wasm` fetch.
//
// When the const is null (the committed default — i.e. local dev +
// tests), Emscripten's default loader fetches the uncompressed
// `./build/clang.wasm` sibling to clang.js, untouched.

const WASM_MAGIC = [0x00, 0x61, 0x73, 0x6d];
const ZSTD_MAGIC = [0x28, 0xb5, 0x2f, 0xfd];

function magicMatch(buf, magic) {
    if (buf.length < 4) return false;
    for (let i = 0; i < 4; i++) if (buf[i] !== magic[i]) return false;
    return true;
}

let _zstdDecompress = null;
async function loadZstd() {
    if (_zstdDecompress) return _zstdDecompress;
    // stage-deploy copies node_modules/fzstd/esm/index.mjs to
    // ./build/fzstd.mjs so this dynamic import resolves with no
    // bundler step. Local dev (CLANG_WASM_VERSION=null) never reaches
    // this path so a missing fzstd.mjs there is fine.
    const m = await import('./build/fzstd.mjs');
    _zstdDecompress = m.decompress;
    return _zstdDecompress;
}

let _cachedClangWasm = null;
async function fetchClangWasm(onProgress) {
    if (_cachedClangWasm) return _cachedClangWasm;

    // Kick off the fzstd loader in parallel with the download — even
    // if we end up not needing it (native browser decoded the body),
    // it's a ~24 KB no-op and the parallel work hides the import
    // latency on browsers that DO need it.
    const zstdPromise = loadZstd();

    const url = new URL(
        `./build/clang.wasm-${CLANG_WASM_VERSION}.zst`,
        import.meta.url,
    );
    const r = await fetch(url);
    if (!r.ok) {
        throw new Error(`fetch ${url}: ${r.status} ${r.statusText}`);
    }
    const lenHeader = r.headers.get('Content-Length');
    const totalBytes = lenHeader ? parseInt(lenHeader, 10) : 0;
    let bytes = 0;
    let lastEmit = 0;
    const emit = (force) => {
        const now = performance.now();
        if (!force && (now - lastEmit) < 50) return;
        lastEmit = now;
        onProgress?.({ stage: 'fetch-clang', bytes, totalBytes });
    };
    emit(true);
    const reader = r.body.getReader();
    const parts = [];
    while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        parts.push(value);
        bytes += value.byteLength;
        emit(false);
    }
    emit(true);
    const merged = new Uint8Array(bytes);
    let off = 0;
    for (const p of parts) { merged.set(p, off); off += p.byteLength; }

    if (magicMatch(merged, WASM_MAGIC)) {
        // Browser handled the Content-Encoding: zstd already; merged
        // is the raw wasm binary, ready to hand to Emscripten.
        _cachedClangWasm = merged.buffer;
        return _cachedClangWasm;
    }
    if (!magicMatch(merged, ZSTD_MAGIC)) {
        throw new Error(
            `clang.wasm bytes start with neither wasm nor zstd magic ` +
            `(got ${[...merged.slice(0, 4)].map(b => b.toString(16).padStart(2, '0')).join(' ')})`,
        );
    }

    // Browser didn't decode zstd for us — do it in JS. fzstd takes
    // ~1 s on ~14 MiB → ~80 MiB on a recent laptop.
    onProgress?.({ stage: 'decompress-clang' });
    const decompress = await zstdPromise;
    const decompressed = decompress(merged);
    _cachedClangWasm = decompressed.slice().buffer;
    return _cachedClangWasm;
}

async function clangModuleOpts(base, onProgress) {
    if (CLANG_WASM_VERSION == null) return base;
    const wasmBinary = await fetchClangWasm(onProgress);
    return { ...base, wasmBinary };
}

// llvm-mov-llc writes its banner ("input module data layout mismatch"
// would-be-warning, the InitLLVM signal handler banner, etc.) to stderr.
// Buffer it and only surface if exit != 0, mirroring movfuscator-wasm.
function makeBuffered() {
    const lines = [];
    return {
        opts: { print: () => {}, printErr: (s) => lines.push(s) },
        joined: () => lines.join('\n'),
    };
}

// Conservative basename guard for opts.name. The string ends up on the
// `.file` directive in the emitted assembly and in MEMFS, so anything
// containing path separators or traversal would break both layers.
function assertSafeName(name) {
    if (typeof name !== 'string' || name.length === 0) {
        throw new TypeError('opts.name must be a non-empty string');
    }
    if (name === '.' || name === '..'
        || name.includes('/') || name.includes('\\')) {
        throw new Error(`opts.name ${JSON.stringify(name)} must be a basename without path separators`);
    }
}

/**
 * Compile LLVM IR (.ll text) to mov-target x86-32 assembly (.s text).
 * @param {string} ir LLVM IR source text. If it lacks a
 *   `target triple = "..."` line, the driver defaults to
 *   `mov-unknown-linux-gnu`.
 * @param {{ name?: string, mtriple?: string, onProgress?: (ev: ProgressEvent) => void }} [opts]
 *   - `name`: basename used for the MEMFS input file. The native driver
 *     bakes the input filename into a `.file "<name>"` directive, so
 *     matching it here is required for byte-identical parity with
 *     native `llvm-mov-llc`. Defaults to `in.ll`.
 *   - `mtriple`: forwarded as `-mtriple=<value>` to llvm-mov-llc to
 *     override the triple baked into the IR. Required when feeding
 *     clang-emitted IR (which carries `i386-unknown-linux-gnu` from
 *     `-target i386-...`) — the driver only accepts a `mov-...` triple
 *     unless one is explicitly forced.
 *   - `onProgress`: status callback. Emits `{ stage: 'instantiate-llc' }`
 *     before Emscripten module init and `{ stage: 'compile-ir' }`
 *     before llvm-mov-llc's main runs.
 * @returns {Promise<string>} mov-target x86-32 GAS-syntax assembly text
 */
export async function compile(ir, opts = {}) {
    if (typeof ir !== 'string') {
        throw new TypeError('ir must be a string');
    }
    const { name = 'in.ll', mtriple, onProgress } = opts;
    assertSafeName(name);
    const args = [`/${name}`, '-o', '/out.s'];
    if (mtriple !== undefined) {
        if (typeof mtriple !== 'string' || mtriple.length === 0) {
            throw new TypeError('opts.mtriple must be a non-empty string');
        }
        args.unshift(`-mtriple=${mtriple}`);
    }
    const buf = makeBuffered();
    onProgress?.({ stage: 'instantiate-llc' });
    const createMovLlc = await loadLlc();
    const llc = await createMovLlc(buf.opts);
    llc.FS.writeFile(`/${name}`, ir);
    onProgress?.({ stage: 'compile-ir' });
    const exit = llc.callMain(args);
    if (exit !== 0) {
        throw new Error(`llvm-mov-llc exited ${exit}\n${buf.joined()}`);
    }
    return llc.FS.readFile('/out.s', { encoding: 'utf8' });
}

// Optimization levels passed through to clang. `-O0` is special:
// clang adds an `optnone` attribute to every function at -O0, which
// disables every IR pass in llvm-mov-llc and breaks the mov-only
// legalize stages on anything non-trivial. We tag `-Xclang
// -disable-O0-optnone` onto -O0 so the IR retains the shape llc
// expects. At -O1+ clang already runs its IR pipeline before
// emit-llvm, no special-casing needed.
const VALID_OPT_LEVELS = new Set(['0', '1', '2', '3', 's', 'z']);
function flagsForOptLevel(level) {
    if (typeof level !== 'string' || !VALID_OPT_LEVELS.has(level)) {
        throw new Error(
            `invalid optLevel ${JSON.stringify(level)}; expected one of ${[...VALID_OPT_LEVELS].join(', ')}`,
        );
    }
    const out = [`-O${level}`];
    if (level === '0') out.push('-Xclang', '-disable-O0-optnone');
    return out;
}

// Base flags passed to clang for the C-frontend step (everything except
// the opt level).
// - `-S -emit-llvm`: stop after LLVM IR generation (don't try to assemble).
// - `-target i386-unknown-linux-gnu`: ABI/data-layout target for the
//   IR. llvm-mov-llc retargets it to `mov-...` via `-mtriple` so the
//   user never has to touch a triple.
// - `-fno-stack-protector -fno-builtin -fno-pic`: keep the IR free of
//   runtime-library shapes the downstream pipeline can't link against
//   (no libc, no PIC GOT).
// - `-fno-ident`: drop the `!llvm.ident` metadata clang otherwise
//   embeds. Its payload is the build's distribution string (e.g.
//   "Debian clang 22.1.6 (...)") which differs between the system
//   clang we use as the parity reference and the wasm clang we build
//   from vendor/llvm-project/. Without this flag the IR and the
//   downstream `.ident` asm directive carry that string and the
//   byte-identical parity test fails for cosmetic reasons.
// - `-nostdinc -nostdlibinc`: the wasm clang only ships its own
//   resource-dir headers (no glibc); blocking the search prevents the
//   driver from looking for system headers that aren't there.
const CLANG_BASE_FLAGS = [
    '-S', '-emit-llvm',
    '-target', 'i386-unknown-linux-gnu',
    // Pin the target-CPU so the IR's `target-cpu` / `target-features`
    // attributes don't drift between the system clang (Debian's i686
    // default) and the vendored upstream clang (pentium4 default).
    // i386 is the lowest baseline; the mov-only legalize stages don't
    // use any extension features anyway.
    '-march=i386',
    '-fno-stack-protector',
    '-fno-builtin',
    '-fno-pic',
    '-fno-ident',
    '-nostdinc', '-nostdlibinc',
];

/**
 * Compile C source text to LLVM IR (.ll text) via clang.wasm.
 * Useful on its own for inspecting the intermediate IR, or chain into
 * `compile()` for the full C → mov-target asm path.
 * @param {string} source C source code.
 * @param {{ name?: string, optLevel?: string, clangFlags?: string[] }} [opts]
 *   - `name`: MEMFS basename of the input file. Defaults to `in.c`.
 *     The basename leaks into the IR's `source_filename` directive, so
 *     parity tests should pass the same basename to both this wrapper
 *     and the native clang they diff against.
 *   - `optLevel`: clang `-O<level>`. One of '0', '1', '2', '3', 's', 'z'.
 *     Defaults to '0'.
 *   - `clangFlags`: extra flags appended to the default set (e.g.
 *     additional `-D` / `-I`).
 * @returns {Promise<string>} LLVM IR text
 */
export async function cToIR(source, opts = {}) {
    if (typeof source !== 'string') {
        throw new TypeError('source must be a string');
    }
    const { name = 'in.c', optLevel = '0', clangFlags = [], onProgress } = opts;
    assertSafeName(name);
    if (!Array.isArray(clangFlags) || !clangFlags.every(f => typeof f === 'string')) {
        throw new TypeError('opts.clangFlags must be a string[]');
    }
    const optFlags = flagsForOptLevel(optLevel);
    const createMovClang = await loadClang();
    const buf = makeBuffered();
    const moduleOpts = await clangModuleOpts(buf.opts, onProgress);
    onProgress?.({ stage: 'instantiate-clang' });
    const clang = await createMovClang(moduleOpts);
    // Stage the file at MEMFS / and pass clang the *bare basename* (not
    // /<name>). Emscripten starts the wasm module with cwd = /, so a
    // bare basename resolves correctly, and the IR's `source_filename`
    // line ends up matching what a native `cd $dir && clang in.c`
    // invocation produces — important for byte-identical parity.
    clang.FS.writeFile(`/${name}`, source);
    const llName = name.replace(/\.c$/, '') + '.ll';
    onProgress?.({ stage: 'compile-c' });
    const exit = clang.callMain([
        ...CLANG_BASE_FLAGS, ...optFlags, ...clangFlags,
        name, '-o', llName,
    ]);
    if (exit !== 0) {
        throw new Error(`clang exited ${exit}\n${buf.joined()}`);
    }
    return clang.FS.readFile(`/${llName}`, { encoding: 'utf8' });
}

/**
 * Compile a C source string to mov-target x86-32 assembly (.s text)
 * through clang + llvm-mov-llc.
 * @param {string} source C source code.
 * @param {{ name?: string, optLevel?: string, clangFlags?: string[] }} [opts]
 *   - Forwarded to `cToIR` (basename, opt level, extra clang flags).
 * @returns {Promise<string>} mov-target x86-32 GAS-syntax assembly text
 */
export async function compileC(source, opts = {}) {
    const ir = await cToIR(source, opts);
    // llvm-mov-llc bakes the input basename into the `.file "..."`
    // directive. Use the same `<stem>.ll` MEMFS basename here that
    // cToIR used, so the parity test sees identical asm between the
    // two-step (cToIR + compile) and one-step (compileC) callers.
    //
    // clang's IR carries `target triple = "i386-unknown-linux-gnu"`
    // (from the `-target i386-...` we hand it). llvm-mov-llc refuses
    // anything that isn't a `mov-...` triple unless `-mtriple` overrides
    // it, so we force-retarget here to the Mov default.
    const llName = (opts.name ?? 'in.c').replace(/\.c$/, '') + '.ll';
    return compile(ir, {
        name: llName,
        mtriple: 'mov-unknown-linux-gnu',
        onProgress: opts.onProgress,
    });
}

// ---------------------------------------------------------------------------
// Rust frontend (in progress)
// ---------------------------------------------------------------------------
//
// `rsToIR(source)` runs a wasm-hosted rustc on a single .rs file and
// returns the LLVM IR text (`--emit=llvm-ir`). The downstream
// `compile()` then takes it to mov-target asm exactly like the C path.
//
// Rust version is selectable via `opts.rustcVersion`, which keys into
// `RUSTC_VERSIONS`. Adding a new rustc.wasm build means appending one
// entry to that table — no wrapper or test changes required. See
// ../CLAUDE.md "Rust frontend (in progress)" for the staged plan and
// the rationale behind starting on the rubrc v0.2.0 (Rust 1.79)
// artefact rather than building our own first.

/**
 * Catalogue of selectable rustc.wasm artefacts. Each entry is the
 * single source of truth for *one* Rust version: where to fetch the
 * compiler wasm and matching sysroot, which targets / editions it can
 * cope with, and how to invoke the equivalent native rustc for parity
 * tests. The wrapper code is intentionally agnostic about *which*
 * version is in use — switching is a one-line opts change.
 */
export const RUSTC_VERSIONS = {
    'rubrc-v0.2.0': {
        // Reported by the artefact at startup as `1.83.0-dev`. That's
        // a snapshot off bjorn3/rust around the 1.83 nightly (between
        // the `compile_rustc_for_wasm16` and `wasm17` branches). The
        // "-dev" suffix flows through to `!llvm.ident` in emitted IR,
        // which is fine for our purposes (we strip / ignore it on the
        // way to the mov backend).
        rustVersion: '1.83.0-dev',
        // Edition 2024 stabilized in 1.85; this artefact predates it.
        editions: ['2015', '2018', '2021'],
        // What rubrc actually ships sysroot tarballs for under
        // rust_wasm/v0.2.0/. i686-unknown-linux-gnu is *not* one of
        // them — that's the gap we'd close by building our own
        // artefact from bjorn3/rust:compile_rustc_for_wasm20 once the
        // spike confirms the rest of the wiring works.
        supportedTargets: ['wasm32-wasip1', 'x86_64-unknown-linux-gnu'],
        artefacts: {
            rustcWasm: 'https://oligamiq.github.io/rust_wasm/v0.2.0/rustc_opt.wasm.br',
            // Per-target sysroot lives at `${sysrootBase}/${triple}.tar.br`.
            sysrootBase: 'https://oligamiq.github.io/rust_wasm/v0.2.0',
            compression: 'brotli',
        },
        // Parity-test hint: tests run `rustup run <nativeRustup> rustc …`
        // so the native reference matches the wasm artefact's Rust
        // version exactly. `1.83.0-dev` isn't a rustup channel — the
        // closest stable for cross-checks is `1.83.0`; full nightly
        // match requires `rustup toolchain link nightly-2024-xx-xx`.
        nativeRustup: '1.83.0',
    },
    // Future expansion:
    //
    // 'self-bjorn3-wasm20': {
    //     rustVersion: '1.96.0',
    //     editions: ['2015', '2018', '2021', '2024'],
    //     supportedTargets: ['i686-unknown-linux-gnu', 'x86_64-unknown-linux-gnu', 'wasm32-wasip1'],
    //     artefacts: {
    //         // self-hosted from scripts/build-wasm-rustc.sh
    //         rustcWasm: '/llvm-mov/rustc-1.96.0.wasm.br',
    //         sysrootBase: '/llvm-mov/sysroot-1.96.0',
    //         compression: 'brotli',
    //     },
    //     nativeRustup: '1.96.0',
    // },
};

export const DEFAULT_RUSTC_VERSION = 'rubrc-v0.2.0';

// Driver is dynamic-imported so callers that don't touch the Rust path
// (e.g. the existing C parity tests) don't pull the WASI shim in.
// Same lazy-load pattern as `loadClang()` above.
let _rustcDriver = null;
async function loadRustcDriver() {
    if (_rustcDriver === null) {
        const m = await import('./lib/rustc-driver.mjs');
        _rustcDriver = m.rsToIRImpl;
    }
    return _rustcDriver;
}

/**
 * Compile a single Rust source file to LLVM IR text via a
 * wasm-hosted rustc.
 *
 * @param {string} source Rust source text.
 * @param {{
 *     name?: string,
 *     rustcVersion?: keyof typeof RUSTC_VERSIONS,
 *     target?: string,
 *     edition?: '2015'|'2018'|'2021'|'2024',
 *     optLevel?: '0'|'1'|'2'|'3'|'s'|'z',
 *     artefacts?: { rustcWasm?: string, sysrootBase?: string },
 *     onProgress?: (ev: { stage: string }) => void,
 * }} [opts]
 *   - `name`: MEMFS basename for the source file. Defaults to `main.rs`.
 *   - `rustcVersion`: registry key. Defaults to `DEFAULT_RUSTC_VERSION`.
 *   - `target`: `--target`. Must be in the version's `supportedTargets`.
 *     Defaults to the first entry there.
 *   - `edition`: `--edition`. Must be in the version's `editions`.
 *     Defaults to `2021`.
 *   - `optLevel`: forwarded as `-C opt-level=…`. No default (rustc's
 *     own default applies — `0` for `--crate-type=lib`).
 *   - `artefacts`: override the version's default URLs. Use this to
 *     point at self-hosted mirrors or to pin a specific bjorn3 build
 *     without editing the registry.
 *   - `onProgress`: status callback. Stages: `fetch-rustc`,
 *     `fetch-sysroot`, `instantiate-wasi`, `run-rustc`.
 * @returns {Promise<string>} LLVM IR text from `--emit=llvm-ir`.
 */
export async function rsToIR(source, opts = {}) {
    if (typeof source !== 'string') {
        throw new TypeError('source must be a string');
    }
    const verKey = opts.rustcVersion ?? DEFAULT_RUSTC_VERSION;
    const spec = RUSTC_VERSIONS[verKey];
    if (!spec) {
        throw new Error(
            `unknown rustcVersion ${JSON.stringify(verKey)}; ` +
            `known: ${Object.keys(RUSTC_VERSIONS).join(', ')}`,
        );
    }
    const target = opts.target ?? spec.supportedTargets[0];
    if (!spec.supportedTargets.includes(target)) {
        throw new Error(
            `target ${JSON.stringify(target)} not supported by ${verKey} ` +
            `(supported: ${spec.supportedTargets.join(', ')})`,
        );
    }
    const edition = opts.edition ?? '2021';
    if (!spec.editions.includes(edition)) {
        throw new Error(
            `edition ${edition} not supported by ${verKey} ` +
            `(supported: ${spec.editions.join(', ')})`,
        );
    }
    const name = opts.name ?? 'main.rs';
    assertSafeName(name);
    const driver = await loadRustcDriver();
    return driver(source, spec, {
        ...opts,
        versionKey: verKey,
        name,
        target,
        edition,
        artefacts: { ...spec.artefacts, ...(opts.artefacts ?? {}) },
    });
}
