// Bench helper: runs the browser-mode wasm pipeline on one .c file.
// Used by scripts/bench.sh under hyperfine. Output is discarded — we
// only care about how long compile() takes.

import { compile } from '../web/movfuscator.mjs';
import { readFileSync } from 'node:fs';

if (process.argv.length < 3) {
    console.error('usage: node bench-browser.mjs FIXTURE.c');
    process.exit(2);
}

const src = readFileSync(process.argv[2], 'utf8');
await compile(src);
