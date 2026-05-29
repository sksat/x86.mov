// Staging smoke — runs against the live Cloudflare Pages preview
// deploy when `E2E_BASE_URL` is set. Validates the deployed bundle's
// two-mode UX:
//   1. Compile → run (llvm-mov path). With the static-link primitive
//      from PR #39 + the explorer wiring in this PR, llvm-mov's output
//      loads into the embedded movie86 cleanly and Run reaches Exit(N).
//      The movfuscator path stays dynamic for now — a separate movie86
//      master_loop dispatch-table fault has to land before that side
//      can also auto-run.
//   2. Optional Upload escape hatch → run an arbitrary static ELF
//      through movie86. Still useful for ELFs the explorer didn't
//      produce.

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

test('staging movfuscator compile populates IR/asm/ELF panes but surfaces the dynamic-link gap', async ({ page }) => {
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

    // Run path is intentionally blocked today on the movfuscator side —
    // the alert tells the user *why*. A separate movie86 master_loop
    // dispatch-table fault has to land before this side can also
    // auto-run. The llvm-mov compile→Run test below covers the happy
    // path that PR #39 + this PR unlock.
    await expect(page.getByTestId('load-error')).toContainText(
        /DynamicLinkingUnsupported|dynamic/i,
        { timeout: 30_000 },
    );
});

test('staging llvm-mov compile auto-loads + Run reaches Exit(42)', async ({ page }) => {
    page.on('pageerror', (err) => console.log('[pageerror]', err.message));

    await page.goto('');

    // llvm-mov is the App.tsx default, but pin it explicitly so the
    // test is robust against the default flipping later.
    await page.getByTestId('compiler-select').click();
    await page.getByRole('option', { name: /llvm-mov/ }).click();

    // The page's preset list already ships a "return 42" entry — same
    // source the movfuscator inspection test uses above. Reusing it
    // here keeps the two paths comparable.
    await page.getByTestId('preset-select').click();
    await page.getByRole('option', { name: /return 42/ }).click();

    await page.getByTestId('compile-button').click();

    await expect(page.getByTestId('status')).toContainText(/compiled in/, {
        timeout: 180_000,
    });

    // The movie86 panel should NOT surface a load-error banner — the
    // static-link + runtime: 'none' combination drops PT_INTERP /
    // PT_DYNAMIC, so `Vm::new` accepts the freshly-compiled ELF.
    await expect(page.getByTestId('load-error')).toHaveCount(0);

    // Run becomes enabled once movie86 finishes the auto-load.
    await expect(page.getByTestId('vm-run')).toBeEnabled({ timeout: 30_000 });
    await page.getByTestId('vm-run').click();

    // _start writes EAX (main's return value, 42) to the mov-only ABI
    // exit address. WasmHost::abi_call decodes that as CALL_EXIT and
    // raises Fault::Exit(42), which surfaces in the status row.
    await expect(page.locator('text=Exit(42)').first()).toBeVisible({
        timeout: 60_000,
    });
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
