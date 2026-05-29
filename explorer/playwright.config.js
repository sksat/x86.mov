// Playwright config for the Explorer E2E. Mirrors llvm-mov/wasm's
// shape: a webserver that runs `vite preview` against a pre-built
// `dist/explorer/`, headless Chromium by default, retries off so CI
// failures surface deterministically.
//
// The full compile pipeline E2E (clang.wasm + as.wasm + ld.wasm) is
// gated on `make build-wasm` having produced the sibling subprojects'
// artifacts. The structural smoke spec runs against any build.

import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
    testDir: 'tests/e2e',
    timeout: 120_000,
    fullyParallel: false,
    workers: 1,
    forbidOnly: !!process.env.CI,
    retries: 0,
    reporter: 'list',
    use: {
        baseURL: process.env.E2E_BASE_URL ?? 'http://localhost:4173/',
        trace: 'retain-on-failure',
    },
    projects: [
        {
            name: 'chromium',
            use: { ...devices['Desktop Chrome'] },
        },
    ],
    webServer: process.env.E2E_BASE_URL
        ? undefined
        : {
              command: 'npm run preview -- --port 4173 --strictPort',
              port: 4173,
              reuseExistingServer: !process.env.CI,
              timeout: 60_000,
          },
});
