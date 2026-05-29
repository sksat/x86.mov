// Staging smoke test — runs against the live Cloudflare Pages preview
// deploy when E2E_BASE_URL is set. Validates that the deployed bundle
// (with the real sibling wasm wrappers in their /movfuscator-wasm/,
// /movie86/, /llvm-mov/ deploy URLs) can drive a compile + run round-
// trip. Kept separate from `structure.spec.ts` because it depends on
// network + the heavy clang.wasm download, so we only run it explicitly.

import { expect, test } from '@playwright/test';

// Skip unless the user explicitly opted into staging.
test.skip(!process.env.E2E_BASE_URL, 'set E2E_BASE_URL to run staging smoke');

test.setTimeout(180_000);

test('staging explorer loads and exposes the major UI surfaces', async ({ page }) => {
    page.on('pageerror', (err) => console.log('[pageerror]', err.message));
    await page.goto('');
    await expect(page.locator('h1')).toContainText('Explorer');
    await expect(page.getByTestId('source-editor')).toBeVisible();
    await expect(page.getByTestId('compiler-select')).toBeVisible();
    await expect(page.getByTestId('compile-button')).toBeVisible();
    await expect(page.getByTestId('asm-pane')).toBeVisible();
});

test('staging movfuscator pipeline compiles return42 and movie86 picks it up', async ({ page }) => {
    page.on('console', (msg) => {
        console.log(`[console.${msg.type()}]`, msg.text());
    });
    page.on('pageerror', (err) => console.log('[pageerror]', err.message));
    page.on('requestfailed', (req) =>
        console.log('[requestfailed]', req.url(), req.failure()?.errorText),
    );

    await page.goto('');

    // Switch to movfuscator — fastest path (no ~80 MB clang.wasm fetch).
    await page.getByTestId('compiler-select').click();
    await page.getByRole('option', { name: /movfuscator/ }).click();

    // Pick the return42 preset — exits with code 42.
    await page.getByTestId('preset-select').click();
    await page.getByRole('option', { name: /return 42/ }).click();

    // Compile. The link step lazy-fetches ~24 MB of crt + libc.
    await page.getByTestId('compile-button').click();

    // The status bar reports "compiled in N ms" on success.
    await expect(page.getByTestId('status')).toContainText(/compiled in/, {
        timeout: 120_000,
    });

    // ELF hexdump appears once the binary lands.
    await expect(page.getByTestId('elf-hexdump')).toBeVisible({ timeout: 5_000 });

    // Wait for the vm-run button to become enabled — that's the
    // signal that movie86 has loaded the freshly-compiled ELF. Until
    // PR #32's loadElf-race fix it would stay disabled forever; pin
    // that explicit transition here so regressions surface fast.
    await expect(page.getByTestId('vm-run')).toBeEnabled({ timeout: 30_000 });
    await page.getByTestId('vm-run').click();
    // return42 halts almost immediately; wait for the halt card to flip.
    await expect(page.locator('text=Exit(42)')).toBeVisible({ timeout: 30_000 });
});
