// Wasm artefact loading config.
//
// clang.wasm is too large (~80 MiB) for Cloudflare Pages' 25 MiB
// per-file upload limit. The deploy ships it zstd-compressed at
// `./build/clang.wasm-{CLANG_WASM_VERSION}.zst` (~14 MiB on the wire).
// CF Pages serves it with `Content-Encoding: zstd` (set in `_headers`);
// modern browsers (Chrome 123+/Firefox 126+/Edge 123+) decompress
// natively at the network layer, others (Safari today) pass the raw
// zstd bytes through and the wrapper decompresses with the bundled
// fzstd module. The wrapper picks between the two paths by inspecting
// the magic bytes of the fetched body, so no UA sniffing.
// The hash in the filename invalidates the immutable HTTP cache the
// moment the binary content changes.
//
// `null` (the committed default) keeps the colocated
// `./build/clang.wasm` behavior for local dev + tests — Emscripten's
// default loader picks up the uncompressed file next to clang.js.
export const CLANG_WASM_VERSION = null;
