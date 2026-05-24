// Bench helper: runs the browser-mode wasm pipeline on one .c file.
// Used by scripts/bench.sh under hyperfine. Output is discarded — we
// only care about how long compile() takes.

import { compile } from '../web/movfuscator.mjs';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, basename, join } from 'node:path';

if (process.argv.length < 3) {
    console.error('usage: node bench-browser.mjs FIXTURE.c');
    process.exit(2);
}

const fixturePath = process.argv[2];
const fixtureDir = dirname(fixturePath);
const src = readFileSync(fixturePath, 'utf8');

// Sibling .h files (e.g. md5.h alongside upstream-md5.c) get loaded into
// MEMFS so quoted #includes resolve like they do in the native pipeline.
const headers = Object.fromEntries(
    readdirSync(fixtureDir)
        .filter(f => f.endsWith('.h'))
        .map(h => [h, readFileSync(join(fixtureDir, h), 'utf8')])
);

await compile(src, headers);
