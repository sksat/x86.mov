import { defineConfig, devices } from '@playwright/test';

// We serve the subproject root over HTTP (not file://) because the wasm
// module loader uses `fetch()` to grab llvm-mov-llc.wasm sibling to the
// .js — `file:` URLs are rejected by the browser's fetch.
const PORT = process.env.E2E_PORT || 8088;

export default defineConfig({
    testDir: './tests/e2e',
    fullyParallel: false, // a single worker is plenty; the wasm is huge
    workers: 1,
    reporter: 'list',
    use: {
        baseURL: `http://127.0.0.1:${PORT}`,
        // The wasm artifact is ~30+ MB; first instantiation in the test
        // browser can take several seconds.
        actionTimeout: 60_000,
        navigationTimeout: 60_000,
    },
    webServer: {
        command: `python3 -m http.server ${PORT} --bind 127.0.0.1`,
        port: PORT,
        reuseExistingServer: !process.env.CI,
        stdout: 'pipe',
        stderr: 'pipe',
    },
    projects: [
        { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    ],
});
