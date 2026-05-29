// E2E parity test for the browser demo at index.html.
//
// Loads the page in a real browser, exercises every (example, opt
// level) pair via the in-page Compile button, and asserts both the
// rendered IR (#ll pane) and the rendered asm (#out pane) equal what
// the native `clang-22 → ../build/bin/llvm-mov-llc` pipeline produces
// from the same C source at the same opt level. That's the same
// byte-identical gate as tests/run.sh, just driven through the actual
// UI instead of the wrapper directly.

import { test, expect } from '@playwright/test';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, readFileSync, mkdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', '..');
// root is llvm-mov/wasm/, so `..` from there → llvm-mov/, then build/bin/llvm-mov-llc.
const native_llc   = join(root, '..', 'build', 'bin', 'llvm-mov-llc');
const native_clang = process.env.CLANG || 'clang-22';

// Same C snippets the demo bundles — duplicated on purpose so a drift
// between this spec and the demo is caught by the strict equality below.
const EXAMPLES = {
    ret_42: `int main(void) {
    return 42;
}
`,
    add_one: `int add_one(int x) {
    return x + 1;
}
`,
    bitand: `int bitand(int a, int b) {
    return a & b;
}
`,
};

// Same opt levels the dropdown exposes. The spec covers -O0 and -O2 —
// the two endpoints that exercise both the `-disable-O0-optnone`
// special-case path and the optimiser-enabled path.
const OPT_LEVELS = ['0', '2'];

// Same base flags llvm-mov.mjs hands to clang. Duplicating here is
// again intentional — drift between wrapper and spec is caught
// immediately by the byte-identical asserts. `-fno-ident` matters:
// the system clang and the vendored wasm clang otherwise stamp
// different distribution strings into `!llvm.ident` and the asm's
// `.ident` directive.
const CLANG_BASE_FLAGS = [
    '-S', '-emit-llvm',
    '-target', 'i386-unknown-linux-gnu',
    '-march=i386',
    '-fno-stack-protector', '-fno-builtin', '-fno-pic',
    '-fno-ident',
    '-nostdinc', '-nostdlibinc',
];

// Reference IR + asm: shell out to native clang+llvm-mov-llc once at
// module load, per (example × opt level). The MEMFS layout the demo
// wrapper uses is `in.c` (bare basename, cwd /) for clang and `in.ll`
// for llvm-mov-llc; we mirror that path layout for the native run too
// so the IR's `source_filename` and the asm's `.file` directive line
// up.
const tmp = mkdtempSync(join(tmpdir(), 'llvm-mov-wasm-e2e-'));
const EXPECTED = {}; // { [name]: { [opt]: { ll: string, s: string } } }
for (const [name, src] of Object.entries(EXAMPLES)) {
    EXPECTED[name] = {};
    for (const opt of OPT_LEVELS) {
        const dir = join(tmp, `${name}.O${opt}`);
        mkdirSync(dir, { recursive: true });
        writeFileSync(join(dir, 'in.c'), src);
        const flags = [...CLANG_BASE_FLAGS, `-O${opt}`];
        if (opt === '0') flags.push('-Xclang', '-disable-O0-optnone');
        execFileSync(native_clang, [...flags, 'in.c', '-o', 'in.ll'], { cwd: dir });
        execFileSync(native_llc, ['-mtriple=mov-unknown-linux-gnu', 'in.ll', '-o', 'in.s'], { cwd: dir });
        EXPECTED[name][opt] = {
            ll: readFileSync(join(dir, 'in.ll'), 'utf8'),
            s:  readFileSync(join(dir, 'in.s'),  'utf8'),
        };
    }
}
process.on('exit', () => rmSync(tmp, { recursive: true, force: true }));

for (const name of Object.keys(EXAMPLES)) {
    for (const opt of OPT_LEVELS) {
        test(`demo compiles "${name}" at -O${opt} with byte-identical parity vs native`, async ({ page }) => {
            const pageErrors = [];
            page.on('pageerror', (e) => pageErrors.push(String(e)));
            if (process.env.E2E_DEBUG) {
                page.on('console', (msg) => console.log(`[console.${msg.type()}]`, msg.text()));
                page.on('requestfailed', (req) => console.log(
                    `[requestfailed] ${req.method()} ${req.url()} :: ${req.failure()?.errorText}`,
                ));
                page.on('response', (resp) => console.log(
                    `[response] ${resp.status()} ${resp.url()}`,
                ));
            }

            // `index.html` (not `/`) so the path component of baseURL
            // is preserved. A leading slash would resolve against the
            // host root and bypass the `/llvm-mov/` prefix that the
            // deployed preview lives under.
            await page.goto('index.html');
            await page.locator('#example').selectOption(name);
            await page.locator('#optLevel').selectOption(opt);

            const input = await page.locator('#in').inputValue();
            expect(input).toBe(EXAMPLES[name]);

            await page.locator('#run').click();

            // The demo flips #status to "compiled in N ms (-O<lvl>)"
            // on success, or .err on failure. First-run compile chains
            // both clang.wasm and llvm-mov-llc.wasm instantiation;
            // budget generously.
            await expect(page.locator('#status')).toHaveText(
                new RegExp(`compiled in \\d+ ms \\(-O${opt}\\)`),
                { timeout: 120_000 },
            );

            const ll  = await page.locator('#ll').innerText();
            const asm = await page.locator('#out').innerText();
            expect(ll).toBe(EXPECTED[name][opt].ll);
            expect(asm).toBe(EXPECTED[name][opt].s);
            expect(pageErrors).toEqual([]);

            // When the run is supposed to exercise the in-browser fzstd
            // fallback (the deploy server is stripping
            // `Content-Encoding: zstd`), prove the wrapper actually
            // took that path: it emits a `decompress-clang` stage
            // event, which the demo renders as "decompress clang" in
            // the timing breakdown below the status line. A
            // byte-identical asm alone wouldn't catch a regression
            // where the native-decode branch silently handled the
            // raw zstd bytes.
            if (process.env.E2E_FZSTD_EXPECTED) {
                await expect(page.locator('#timing')).toContainText('decompress clang');
            }
        });
    }
}
