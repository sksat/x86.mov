// Structural smoke test. Asserts the page renders the expected
// surface area without driving an actual compile — that requires the
// sibling subprojects' `make build` artifacts (clang.wasm,
// llvm-mov-llc.wasm, movie86_wasm_bg.wasm, as.wasm, ld.wasm) which
// land later in CI. The compile-flow spec (next file) is gated on
// those.

import { expect, test } from '@playwright/test';

test('Explorer renders the major panes', async ({ page }) => {
    await page.goto('/');

    // Header + title.
    await expect(page.locator('h1')).toContainText('Explorer');

    // Compiler-explorer-style top strip is present.
    await expect(page.getByTestId('explorer-strip')).toBeVisible();
    await expect(page.getByTestId('source-editor')).toBeVisible();
    await expect(page.getByTestId('preset-select')).toBeVisible();
    await expect(page.getByTestId('compiler-select')).toBeVisible();
    await expect(page.getByTestId('compile-button')).toBeVisible();

    // Output column lives in a single Tabs panel — `asm` is the
    // default tab; the asm CodeViewer is visible without clicking
    // anything. Pin the asm pane visibility + tab strip presence.
    await expect(page.getByTestId('output-tabs')).toBeVisible();
    await expect(page.getByTestId('asm-pane')).toBeVisible();

    // IR pane is visible only when llvm-mov is the active compiler.
    // Initial state is llvm-mov (App.tsx default).
    await expect(page.getByTestId('ir-pane')).toBeVisible();

    // movie86 panel + handover.
    await expect(page.locator('text=Run · movie86').first()).toBeVisible();
    await expect(page.getByTestId('turbo86-handover')).toBeVisible();
});

test('Movie86 panel exposes a live Follow toggle + step-delay control', async ({
    page,
}) => {
    await page.goto('/');

    const follow = page.getByTestId('vm-follow');
    const delay = page.getByTestId('vm-delay');
    await expect(follow).toBeVisible();
    await expect(delay).toBeVisible();

    // Default is Follow on (watch each mov land), so the step-delay
    // input — only meaningful in follow mode — starts enabled.
    await expect(follow).toBeChecked();
    await expect(delay).toBeEnabled();

    // Toggling is plain UI state, so it works without a loaded Vm (and,
    // in turn, can be flipped while a run is in flight — the run loop
    // reads it live). Off disables the delay input; on re-enables it.
    await follow.uncheck();
    await expect(follow).not.toBeChecked();
    await expect(delay).toBeDisabled();

    await follow.check();
    await expect(delay).toBeEnabled();
});

test('Compiler select hides the IR column when movfuscator is chosen', async ({ page }) => {
    await page.goto('/');
    // The IR column is mounted initially (llvm-mov default).
    await expect(page.getByTestId('ir-pane')).toBeVisible();

    // Switch compiler → movfuscator. The IR column unmounts (the
    // strip flips to 2 columns).
    await page.getByTestId('compiler-select').click();
    await page.getByRole('option', { name: /movfuscator/ }).click();
    await expect(page.getByTestId('ir-pane')).toHaveCount(0);

    // asm pane (default tab in the Output column) is still visible.
    await expect(page.getByTestId('asm-pane')).toBeVisible();
});

test('Output tabs switch between asm and binary; asm is the default', async ({ page }) => {
    await page.goto('/');
    // Default tab is `asm` — its [data-state="active"] flips on the
    // trigger and the asm pane is in the visible TabsContent.
    await expect(page.getByTestId('output-tab-asm')).toHaveAttribute(
        'data-state',
        'active',
    );
    await expect(page.getByTestId('asm-pane')).toBeVisible();

    // Click the binary tab. The Tabs primitive only renders the
    // active TabsContent's children, so the asm pane unmounts.
    await page.getByTestId('output-tab-binary').click();
    await expect(page.getByTestId('output-tab-binary')).toHaveAttribute(
        'data-state',
        'active',
    );
    await expect(page.getByTestId('asm-pane')).toHaveCount(0);
});

test('Preset switch swaps the source contents', async ({ page }) => {
    await page.goto('/');
    await page.getByTestId('preset-select').click();
    await page.getByRole('option', { name: /sum10/ }).click();
    // CodeMirror renders `.cm-content` per editor — scope to the
    // source pane so we don't pick up the IR / asm read-only viewers.
    await expect(
        page.getByTestId('source-editor').locator('.cm-content'),
    ).toContainText('sum = sum + i');
});
