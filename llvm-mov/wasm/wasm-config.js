// Wasm artefact loading config.
//
// `clang.wasm` is too large for Cloudflare Pages' 25 MiB/file limit so
// the deploy hosts it on a GitHub Release instead (see
// scripts/stage-deploy.sh + the deploy workflow). At stage-deploy
// time the placeholder `null` below is substituted with the release
// asset URL. When unset (local dev, tests), llvm-mov.mjs falls back to
// the colocated `./build/clang.wasm`.
export const CLANG_WASM_URL = null;
