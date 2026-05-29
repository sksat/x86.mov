// rustc-driver.mjs
//
// Drives a wasm-hosted rustc artefact via @bjorn3/browser_wasi_shim.
// The caller (llvm-mov.mjs `rsToIR`) passes a `spec` from
// `RUSTC_VERSIONS`, so this module stays agnostic about which Rust
// version is in use — adding a new artefact = a new registry entry.
//
// Status: structural stub. The fetch + WASI + invoke wiring is the
// next step; landing it is what flips `tests/run-rust.sh` from RED
// (current) to GREEN. See ../CLAUDE.md "Rust frontend (in progress)"
// for the staged plan.
//
// Sketch of the implementation:
//
//   1. fetch rustc.wasm    spec.artefacts.rustcWasm
//                          → brotli-decompress (compression=brotli)
//                          → WebAssembly.compile → cached Module
//   2. fetch sysroot       `${spec.artefacts.sysrootBase}/${opts.target}.tar.br`
//                          → brotli-decompress → parse-tar → Directory tree
//                          → mounted at /sysroot/lib/rustlib/<target>/lib/
//   3. assemble MEMFS:     /<opts.name>      = source
//                          /sysroot/...      = sysroot tree
//                          /tmp/             = empty (rustc writes here)
//   4. WASI instance:      args = [
//                              'rustc', `/${opts.name}`,
//                              '--sysroot', '/sysroot',
//                              '--target', opts.target,
//                              '--edition', opts.edition,
//                              '--crate-type=lib',
//                              '--emit=llvm-ir',
//                              '--out-dir', '/tmp',
//                              ...(opts.optLevel
//                                  ? ['-C', `opt-level=${opts.optLevel}`]
//                                  : []),
//                          ]
//                          stdout/stderr → buffer; exit code 0 expected.
//   5. read /tmp/<crate>.ll → return as string
//
// Building blocks we'll reach for:
//   - @oligami/rustc-browser-wasi_shim: `get_wasm`, `load_sysroot_part`
//     (brotli + tar parsing, already tested by rubrc)
//   - @bjorn3/browser_wasi_shim: WASI, PreopenDirectory, File, ...
//   - Optionally @oligami/browser_wasi_shim-threads for the threaded
//     variant (needs SharedArrayBuffer + COOP/COEP — fine for the
//     explorer page; tighter constraints in Node test mode).
//
// Neither package is in package.json yet — that's the next chunk.

export async function rsToIRImpl(_source, spec, opts) {
    const artefacts = opts.artefacts;
    throw new Error(
        `rsToIR driver not yet implemented for ${spec.rustVersion} ` +
        `(target=${opts.target}, edition=${opts.edition}). ` +
        `Next step: npm install @oligami/rustc-browser-wasi_shim ` +
        `@bjorn3/browser_wasi_shim, then wire the 5-step flow ` +
        `documented in lib/rustc-driver.mjs. ` +
        `Artefact URLs: ${artefacts.rustcWasm} + ` +
        `${artefacts.sysrootBase}/${opts.target}.tar.br`,
    );
}
