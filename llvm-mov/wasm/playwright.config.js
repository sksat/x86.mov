import { defineConfig, devices } from '@playwright/test';

// `E2E_BASE_URL` aims the spec at an already-running host (e.g. the
// Cloudflare Pages preview). When unset, we serve locally — wasm
// module loaders use `fetch()` to grab .wasm sibling files, and
// `file:` URLs are rejected by the browser's fetch.
//
// Two local modes:
//   - default: serve the subproject root (`llvm-mov/wasm/`) over
//     `python -m http.server`. clang.wasm is uncompressed and lives
//     next to clang.js — Emscripten's loader picks it up directly.
//     wasm-config.js is unmodified, so the zstd path is dormant.
//   - `E2E_SERVE_DIST=1`: serve the *staged deploy* under repo-root
//     `dist/`. wasm-config.js has CLANG_WASM_VERSION set, the wrapper
//     fetches `clang.wasm-{hash}.zst`, and the dist server applies
//     `dist/_headers` (Content-Encoding: zstd, Content-Type:
//     application/wasm) the same way CF Pages does. This exercises
//     the production-shape loader against locally-served files.
const REMOTE_BASE_URL = process.env.E2E_BASE_URL;
const SERVE_DIST = process.env.E2E_SERVE_DIST === '1';
const PORT = process.env.E2E_PORT || (SERVE_DIST ? 8089 : 8088);

export default defineConfig({
    testDir: './tests/e2e',
    fullyParallel: false, // a single worker is plenty; the wasm is huge
    workers: 1,
    reporter: 'list',
    use: {
        baseURL: REMOTE_BASE_URL
            || (SERVE_DIST ? `http://127.0.0.1:${PORT}/llvm-mov/` : `http://127.0.0.1:${PORT}`),
        // The wasm artifact is ~30+ MB; first instantiation in the test
        // browser can take several seconds. Remote runs add ~1 RTT on top.
        actionTimeout: 60_000,
        navigationTimeout: 60_000,
    },
    // Only start the local static server when we're not pointed at a
    // remote URL. Omitting the property entirely (vs. setting it null)
    // is the documented way to disable the auto-managed server.
    ...(REMOTE_BASE_URL ? {} : {
        webServer: {
            command: SERVE_DIST
                ? `node tests/serve-dist.mjs`
                : `python3 -m http.server ${PORT} --bind 127.0.0.1`,
            port: PORT,
            reuseExistingServer: !process.env.CI,
            stdout: 'pipe',
            stderr: 'pipe',
        },
    }),
    projects: [
        { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    ],
});
