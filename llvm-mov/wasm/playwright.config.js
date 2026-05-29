import { defineConfig, devices } from '@playwright/test';

// `E2E_BASE_URL` aims the spec at an already-running host (e.g. the
// Cloudflare Pages preview). When unset, we serve the subproject root
// over a local HTTP server — wasm module loaders use `fetch()` to grab
// .wasm sibling files, and `file:` URLs are rejected by the browser's
// fetch.
const REMOTE_BASE_URL = process.env.E2E_BASE_URL;
const PORT = process.env.E2E_PORT || 8088;

export default defineConfig({
    testDir: './tests/e2e',
    fullyParallel: false, // a single worker is plenty; the wasm is huge
    workers: 1,
    reporter: 'list',
    use: {
        baseURL: REMOTE_BASE_URL || `http://127.0.0.1:${PORT}`,
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
            command: `python3 -m http.server ${PORT} --bind 127.0.0.1`,
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
