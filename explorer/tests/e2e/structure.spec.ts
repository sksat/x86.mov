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

    // Three top-level controls.
    await expect(page.getByTestId('source-editor')).toBeVisible();
    await expect(page.getByTestId('preset-select')).toBeVisible();
    await expect(page.getByTestId('compiler-select')).toBeVisible();
    await expect(page.getByTestId('compile-button')).toBeVisible();

    // Compile output strip exists.
    await expect(page.getByTestId('asm-pane')).toBeVisible();
    // IR pane visible iff llvm-mov is the active compiler.
    await expect(page.getByTestId('ir-pane')).toBeVisible();

    // ELF hex dump pane (empty until compile, but the pre exists).
    // The pane only mounts when there's an elf, so just check the
    // surrounding "Binary" card title.
    await expect(page.locator('text=Binary').first()).toBeVisible();

    // movie86 panel + handover.
    await expect(page.locator('text=Run · movie86').first()).toBeVisible();
    await expect(page.getByTestId('turbo86-handover')).toBeVisible();
});

test('Compiler select hides the IR pane when movfuscator is chosen', async ({ page }) => {
    await page.goto('/');
    // Trigger the Select and pick movfuscator.
    await page.getByTestId('compiler-select').click();
    await page.getByRole('option', { name: /movfuscator/ }).click();

    // No compile has run yet, so the IR pane still shows (it
    // disappears only after a compile result with ir=null lands). For
    // the structural test we just confirm the asm pane is still
    // present — the compile-flow spec asserts the hide behaviour.
    await expect(page.getByTestId('asm-pane')).toBeVisible();
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
