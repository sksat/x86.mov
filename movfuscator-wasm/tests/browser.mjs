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
    join(buildDir, 'as.js'),
    join(buildDir, 'as.wasm'),
    join(buildDir, 'ld.js'),
    join(buildDir, 'ld.wasm'),
    wrapper,
];
const missing = required.filter(p => !existsSync(p));
if (missing.length) {
    console.error('FAIL: required artifacts missing — run "make build-wasm-browser build-wasm-as-browser build-wasm-ld-browser" first');
    for (const p of missing) console.error('  missing:', p);
    process.exit(1);
}

const { compile, assemble, link, LIB_PATHS } = await import(wrapper);
const goldensO = join(root, 'tests', 'goldens-o');
const libDir = join(root, 'web', 'lib');

// Pre-load the link libs from web/lib/ so we don't fetch them via HTTP in
// Node tests. Same Uint8Array map the browser default-fetch produces;
// the path list is the canonical one re-exported from the wrapper.
let preloadedLibs = null;
if (existsSync(libDir)) {
    preloadedLibs = {};
    for (const p of LIB_PATHS) {
        const stagedPath = join(libDir, p.replace(/^\//, ''));
        if (!existsSync(stagedPath)) {
            console.error(`web/lib missing: ${stagedPath} — run 'make stage-link-libs'`);
            process.exit(1);
        }
        preloadedLibs[p] = readFileSync(stagedPath);
    }
}

const headerFiles = readdirSync(fixtures).filter(f => f.endsWith('.h'));
const headers = Object.fromEntries(
    headerFiles.map(h => [h, readFileSync(join(fixtures, h), 'utf8')])
);

let pass = 0, fail = 0;
const cFiles = readdirSync(fixtures).filter(f => f.endsWith('.c')).sort();

console.log('— compile() (.c → .s) —');
for (const file of cFiles) {
    const name = basename(file, '.c');
    const goldenPath = join(goldens, `${name}.s`);
    if (!existsSync(goldenPath)) {
        console.log(`SKIP ${name} (no .s golden)`);
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
        console.log(`FAIL ${name} — compile output differs from golden`);
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
console.log('— assemble() (.s → .o) —');
for (const file of cFiles) {
    const name = basename(file, '.c');
    const sPath = join(goldens, `${name}.s`);
    const oPath = join(goldensO, `${name}.o`);
    if (!existsSync(sPath) || !existsSync(oPath)) {
        console.log(`SKIP ${name} (missing .s or .o golden)`);
        continue;
    }
    const asm = readFileSync(sPath, 'utf8');
    const expectedBytes = readFileSync(oPath);
    let actualBytes;
    try {
        actualBytes = await assemble(asm);
    } catch (e) {
        console.log(`FAIL ${name} — assemble threw:`);
        console.log('  |', String(e.message || e).split('\n').join('\n  | '));
        fail++;
        continue;
    }
    if (actualBytes.length === expectedBytes.length && actualBytes.every((b, i) => b === expectedBytes[i])) {
        console.log(`PASS ${name} (${actualBytes.length} bytes)`);
        pass++;
    } else {
        console.log(`FAIL ${name} — wasm .o differs from golden`);
        console.log(`  | golden=${expectedBytes.length} actual=${actualBytes.length}`);
        fail++;
    }
}

if (preloadedLibs) {
    console.log();
    console.log('— link() (.o → ELF) —');
    // Pre-stage required vendor build artifacts for native ld reference link.
    const childProcess = await import('node:child_process');
    const { spawnSync } = childProcess;
    const B = join(root, 'vendor/movfuscator/build');
    const SF = join(root, 'vendor/movfuscator/movfuscator/lib');

    for (const file of cFiles) {
        const name = basename(file, '.c');
        // multi-* fixtures are pieces of a multi-input link — exercised
        // by tests/run-multi.mjs, not this single-object loop.
        if (name.startsWith('multi-')) continue;
        const oPath = join(goldensO, `${name}.o`);
        if (!existsSync(oPath)) {
            console.log(`SKIP ${name} (no .o golden)`);
            continue;
        }
        const obj = readFileSync(oPath);

        // Reference: native ld linking the same .o + libs.
        const tmpNativeElf = `/tmp/test-browser-${name}-native.elf`;
        const native = spawnSync('/usr/bin/ld', [
            '-m', 'elf_i386', '--hash-style=gnu',
            '-dynamic-linker', '/lib/ld-linux.so.2',
            '-L', B, '-L', `${B}/gcc/32`, '-L', '/usr/lib32', '-L', '/lib32',
            '-lgcc', '-lc', '-lm',
            `${B}/crt0.o`, oPath, `${B}/crtf.o`, `${B}/crtd.o`, `${SF}/softfloat32.o`,
            '-o', tmpNativeElf,
        ]);
        if (native.status !== 0) {
            console.log(`SKIP ${name} (native ld failed — likely missing host tooling)`);
            continue;
        }
        const expected = readFileSync(tmpNativeElf);

        let actual;
        try {
            actual = await link(obj, preloadedLibs, { name: `${name}.o` });
        } catch (e) {
            console.log(`FAIL ${name} — link threw:`);
            console.log('  |', String(e.message || e).split('\n').join('\n  | '));
            fail++;
            continue;
        }

        if (actual.length === expected.length && actual.every((b, i) => b === expected[i])) {
            console.log(`PASS ${name} (${actual.length} bytes)`);
            pass++;
        } else {
            console.log(`FAIL ${name} — wasm ELF differs from native ld`);
            console.log(`  | native=${expected.length} wasm=${actual.length}`);
            fail++;
        }
    }
}

console.log();
console.log(`results: ${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
