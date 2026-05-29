// Wasm artefact loading config.
//
// `clang.wasm` is too large (~76 MiB) for Cloudflare Pages' 25 MiB
// per-file upload limit, so the deploy splits it into ≤24 MiB chunks
// (`clang.wasm.part-0..N`) and the wrapper concatenates them client-
// side. `CLANG_WASM_CHUNKS` is the chunk count; stage-deploy.sh sets it
// before staging. `null` (the committed default) keeps the colocated
// `./build/clang.wasm` behavior for local dev + tests.
export const CLANG_WASM_CHUNKS = null;
