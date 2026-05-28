// E2E parity test for the browser demo at index.html.
//
// Loads the page in a real browser, selects each built-in example, runs
// the in-page compile button, and asserts the emitted `.s` text equals
// what the native `../llvm-mov/build/bin/llvm-mov-llc` produces from the
// same IR. The byte-equality matches the node-mode `tests/run.sh`, just
// driven through the actual UI instead of the wrapper directly.

import { test, expect } from '@playwright/test';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', '..');
const native = join(root, '..', 'llvm-mov', 'build', 'bin', 'llvm-mov-llc');

// Pull the same IR snippets the demo bundles so the spec is the single
// source of truth — if the demo's EXAMPLES drift, the spec catches it.
const EXAMPLES = {
    ret_42: `target triple = "mov-unknown-linux-gnu"

define i32 @main() {
  ret i32 42
}
`,
    add_one: `target triple = "mov-unknown-linux-gnu"

define i32 @add_one(i32 %x) {
  %r = add i32 %x, 1
  ret i32 %r
}
`,
    bitand: `target triple = "mov-unknown-linux-gnu"

define i32 @bitand(i32 %a, i32 %b) {
  %r = and i32 %a, %b
  ret i32 %r
}
`,
};

// Reference asm: shell out to native llvm-mov-llc once at module load,
// not per test. The IR strings above are baked into both the demo and
// the spec; the spec runs native on them and reuses the output as the
// expected value. This is the same byte-identical assertion shape
// tests/run.sh uses for the node-mode parity test.
//
// LLVM bakes the input basename into the emitted `.s` as a
// `.file "<basename>"` directive. The demo wrapper feeds its textarea
// content to `compile()` without an `opts.name`, so the wasm side
// always sees `in.ll` — we mirror that here so the spec compares like
// for like. (If we passed each fixture's own name, the spec would
// silently drift the moment the demo's textarea didn't carry one.)
const DEMO_BASENAME = 'in.ll';
const tmp = mkdtempSync(join(tmpdir(), 'llvm-mov-wasm-e2e-'));
const EXPECTED = {};
for (const [name, ir] of Object.entries(EXAMPLES)) {
    const llPath = join(tmp, DEMO_BASENAME);
    const sPath  = join(tmp, `${name}.s`);
    writeFileSync(llPath, ir);
    execFileSync(native, [llPath, '-o', sPath]);
    EXPECTED[name] = readFileSync(sPath, 'utf8');
}
process.on('exit', () => rmSync(tmp, { recursive: true, force: true }));

for (const name of Object.keys(EXAMPLES)) {
    test(`demo compiles "${name}" with byte-identical parity vs native`, async ({ page }) => {
        // Surface load-time errors from the page (wasm import failures,
        // module-loader errors, etc.) into the test report instead of
        // hiding inside the browser console.
        const pageErrors = [];
        page.on('pageerror', (e) => pageErrors.push(String(e)));

        await page.goto('/');
        await page.locator('#example').selectOption(name);

        // The IR textarea is filled by the demo's `loadExample()` on
        // 'change'. Sanity-check the input matches the spec's copy
        // before we hit Compile; if it doesn't, the demo and the spec
        // have drifted and the parity assertion below would be a lie.
        const input = await page.locator('#in').inputValue();
        expect(input).toBe(EXAMPLES[name]);

        await page.locator('#run').click();

        // status flips to "compiled in N ms" on success, or .err on
        // failure — wait for either so the test fails fast on errors
        // instead of timing out on the empty output element.
        await expect(page.locator('#status')).toHaveText(/compiled in \d+ ms/, {
            timeout: 60_000,
        });

        const asm = await page.locator('#out').innerText();
        expect(asm).toBe(EXPECTED[name]);
        expect(pageErrors).toEqual([]);
    });
}
