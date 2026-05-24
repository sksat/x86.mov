// End-to-end browser-mode test runner.
//
// Drives the MEMFS-mode wasm pipeline (build/browser/cpp.{js,wasm} +
// build/browser/rcc.{js,wasm}) via the JS wrapper at web/movfuscator.mjs.
// For every tests/fixtures/*.c, calls compile() and asserts the returned
// string is byte-identical to the committed tests/goldens/*.s.
//
// This is the parallel safety net to tests/run.sh — the latter exercises
// the Node-NODERAWFS pipeline (used during dev), this one exercises the
// pipeline that actually ships to the browser.

import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, basename } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const root = dirname(here);
const buildDir = join(root, 'build', 'browser');
const wrapper = join(root, 'web', 'movfuscator.mjs');
const fixtures = join(root, 'tests', 'fixtures');
const goldens = join(root, 'tests', 'goldens');

const required = [
    join(buildDir, 'cpp.js'),
    join(buildDir, 'cpp.wasm'),
    join(buildDir, 'rcc.js'),
    join(buildDir, 'rcc.wasm'),
    wrapper,
];
const missing = required.filter(p => !existsSync(p));
if (missing.length) {
    console.error('FAIL: required artifacts missing — run "make build-wasm-browser" first');
    for (const p of missing) console.error('  missing:', p);
    process.exit(1);
}

const { compile } = await import(wrapper);

// Preload any tests/fixtures/*.h sidecars (e.g. md5.h) so MEMFS resolves
// `#include "name.h"` the same way the native preprocess.sh does when it
// runs from the same directory as the .c file.
const headerFiles = readdirSync(fixtures).filter(f => f.endsWith('.h'));
const headers = Object.fromEntries(
    headerFiles.map(h => [h, readFileSync(join(fixtures, h), 'utf8')])
);

let pass = 0, fail = 0;
const cFiles = readdirSync(fixtures).filter(f => f.endsWith('.c')).sort();
for (const file of cFiles) {
    const name = basename(file, '.c');
    const goldenPath = join(goldens, `${name}.s`);
    if (!existsSync(goldenPath)) {
        console.log(`SKIP ${name} (no golden)`);
        continue;
    }
    const source = readFileSync(join(fixtures, file), 'utf8');
    const expected = readFileSync(goldenPath, 'utf8');

    let actual;
    try {
        actual = await compile(source, headers);
    } catch (e) {
        console.log(`FAIL ${name} — compile threw:`);
        console.log('  |', String(e.message || e).split('\n').join('\n  | '));
        fail++;
        continue;
    }

    if (actual === expected) {
        console.log(`PASS ${name} (${actual.split('\n').length - 1} lines)`);
        pass++;
    } else {
        console.log(`FAIL ${name} — wasm output differs from golden`);
        // Show first divergence to help debug
        const aLines = actual.split('\n');
        const eLines = expected.split('\n');
        for (let i = 0; i < Math.min(aLines.length, eLines.length); i++) {
            if (aLines[i] !== eLines[i]) {
                console.log(`  | first diff at line ${i + 1}:`);
                console.log(`  |   expected: ${JSON.stringify(eLines[i])}`);
                console.log(`  |   actual:   ${JSON.stringify(aLines[i])}`);
                break;
            }
        }
        fail++;
    }
}

console.log();
console.log(`results: ${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
