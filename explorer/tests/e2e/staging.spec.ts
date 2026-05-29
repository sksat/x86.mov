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

test('staging movfuscator compile populates IR/asm/ELF panes but surfaces the static-link gap', async ({ page }) => {
    page.on('pageerror', (err) => console.log('[pageerror]', err.message));

    await page.goto('');

    // Switch to movfuscator — fastest path (no ~80 MB clang.wasm fetch).
    await page.getByTestId('compiler-select').click();
    await page.getByRole('option', { name: /movfuscator/ }).click();

    // Pick the return42 preset.
    await page.getByTestId('preset-select').click();
    await page.getByRole('option', { name: /return 42/ }).click();

    // Compile. Link lazy-fetches ~24 MB of crt + libc on the first call.
    await page.getByTestId('compile-button').click();

    await expect(page.getByTestId('status')).toContainText(/compiled in/, {
        timeout: 120_000,
    });

    // The middle pane shows the compiled artifact even when movie86
    // can't load it — Compile → inspect is the supported path today.
    await expect(page.getByTestId('elf-hexdump')).toBeVisible({ timeout: 5_000 });

    // The dynamic-link gap surfaces in the Movie86 panel's alert
    // (see CLAUDE.md Known limitations). Pin that the user sees the
    // explanation rather than a dead disabled button.
    await expect(page.getByTestId('load-error')).toContainText(
        /DynamicLinkingUnsupported|dynamic/i,
        { timeout: 30_000 },
    );
});

test('staging example fixture round-trips through movie86 to Exit(42)', async ({ page }) => {
    page.on('pageerror', (err) => console.log('[pageerror]', err.message));

    await page.goto('');

    // Pick the return42 static fixture from the example dropdown.
    await page.getByTestId('example-select').click();
    await page.getByRole('option', { name: /return42/ }).click();

    // Static ELF loads cleanly; Run is enabled.
    await expect(page.getByTestId('vm-run')).toBeEnabled({ timeout: 30_000 });
    await page.getByTestId('vm-run').click();

    // return42 halts on Exit(42) almost immediately.
    await expect(page.locator('text=Exit(42)').first()).toBeVisible({
        timeout: 30_000,
    });
});
