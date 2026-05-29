// Staging smoke — runs against the live Cloudflare Pages preview
// deploy when `E2E_BASE_URL` is set. Validates the deployed bundle's
// two-mode UX:
//   1. Compile → inspect (IR / asm / ELF panes). The movie86 panel
//      auto-loads and surfaces the dynamic-link gap as a banner
//      (issue #36 will close the gap by adding `static: true` to
//      movfuscator-wasm's `link()`; until then this is the expected
//      shape).
//   2. Optional Upload escape hatch → run an arbitrary static ELF
//      through movie86.

import { expect, test } from '@playwright/test';

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
    // Optional escape hatch lives in the Movie86 panel header.
    await expect(page.getByTestId('elf-upload')).toBeVisible();
});

test('staging movfuscator compile populates IR/asm/ELF panes but surfaces the static-link gap', async ({ page }) => {
    page.on('pageerror', (err) => console.log('[pageerror]', err.message));

    await page.goto('');

    await page.getByTestId('compiler-select').click();
    await page.getByRole('option', { name: /movfuscator/ }).click();

    await page.getByTestId('preset-select').click();
    await page.getByRole('option', { name: /return 42/ }).click();

    await page.getByTestId('compile-button').click();

    await expect(page.getByTestId('status')).toContainText(/compiled in/, {
        timeout: 120_000,
    });

    // Inspect path works.
    await expect(page.getByTestId('elf-hexdump')).toBeVisible({ timeout: 5_000 });

    // Run path is intentionally blocked today — the alert tells the
    // user *why*. Closing #36 will make this assertion start failing
    // and a Run-after-compile test should take its place.
    await expect(page.getByTestId('load-error')).toContainText(
        /DynamicLinkingUnsupported|dynamic/i,
        { timeout: 30_000 },
    );
});

test('staging Upload escape hatch runs a static ELF to Exit(42)', async ({ page }) => {
    page.on('pageerror', (err) => console.log('[pageerror]', err.message));

    await page.goto('');

    // Grab a known static ELF (return42.elf, already on the deploy
    // via movie86/wasm stage-deploy) and feed it through the Upload
    // input. Mirrors what the user would do today with an arbitrary
    // statically-linked ELF.
    const elfBytes = await page.evaluate(async () => {
        const r = await fetch('/movie86/examples/return42.elf');
        if (!r.ok) throw new Error(`return42.elf fetch: ${r.status}`);
        const buf = await r.arrayBuffer();
        return Array.from(new Uint8Array(buf));
    });

    await page.getByTestId('elf-upload-input').setInputFiles({
        name: 'return42.elf',
        mimeType: 'application/octet-stream',
        buffer: Buffer.from(elfBytes),
    });

    await expect(page.getByTestId('vm-run')).toBeEnabled({ timeout: 30_000 });
    await page.getByTestId('vm-run').click();
    await expect(page.locator('text=Exit(42)').first()).toBeVisible({
        timeout: 30_000,
    });
});
