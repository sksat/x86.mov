// Wasm artefact loading config.
//
// `clang.wasm` is too large (~76 MiB) for Cloudflare Pages' 25 MiB
// per-file upload limit, so the deploy splits it into ≤24 MiB chunks
// (`clang.wasm.part-0..N`) and the wrapper concatenates them client-
// side. `CLANG_WASM_CHUNKS` is the chunk count and
// `CLANG_WASM_VERSION` is a short content hash of clang.wasm;
// stage-deploy.sh sets both before staging. The hash is woven into
// the deployed chunk filenames (`clang.wasm-{hash}.part-i`) so the
// URL changes on a binary bump while the unchanged URL stays in the
// browser's HTTP cache forever (CF Pages `_headers` sets `Cache-
// Control: immutable` for the chunk pattern).
//
// `null` (the committed default) keeps the colocated
// `./build/clang.wasm` behavior for local dev + tests.
export const CLANG_WASM_CHUNKS = null;
export const CLANG_WASM_VERSION = null;
